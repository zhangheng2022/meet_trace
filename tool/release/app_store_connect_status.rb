# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "time"
require "uri"

API_ROOT = "https://api.appstoreconnect.apple.com/v1"
MAXIMUM_RESPONSE_BYTES = 512 * 1024
MAXIMUM_GROUP_BUILD_PAGES = 20

class AppStoreConnectQueryError < StandardError
  attr_reader :stage, :http_status, :error_codes, :error_titles

  def initialize(stage:, http_status:, error_codes:, error_titles:)
    super("App Store Connect request failed")
    @stage = stage
    @http_status = http_status
    @error_codes = error_codes
    @error_titles = error_titles
  end
end

class AppStoreConnectInvariantError < StandardError
  attr_reader :stage, :reason_code

  def initialize(stage:, reason_code:, message:)
    super(message)
    @stage = stage
    @reason_code = reason_code
  end
end

options = {}
OptionParser.new do |parser|
  parser.on("--key-id VALUE") { |value| options[:key_id] = value }
  parser.on("--issuer-id VALUE") { |value| options[:issuer_id] = value }
  parser.on("--private-key PATH") { |value| options[:private_key] = value }
  parser.on("--bundle-id VALUE") { |value| options[:bundle_id] = value }
  parser.on("--marketing-version VALUE") { |value| options[:marketing_version] = value }
  parser.on("--build-number VALUE") { |value| options[:build_number] = value }
  parser.on("--external-group VALUE") { |value| options[:external_group] = value }
  parser.on("--public-link VALUE") { |value| options[:public_link] = value }
  parser.on("--diagnostic PATH") { |value| options[:diagnostic] = value }
end.parse!
required = %i[key_id issuer_id private_key bundle_id marketing_version build_number external_group public_link]
missing = required.select { |name| options[name].to_s.strip.empty? }
raise OptionParser::MissingArgument, missing.join(", ") unless missing.empty?

ENV["APP_STORE_CONNECT_KEY_ID"] = options.fetch(:key_id)
ENV["APP_STORE_CONNECT_ISSUER_ID"] = options.fetch(:issuer_id)
ENV["APP_STORE_CONNECT_API_KEY_PATH"] = options.fetch(:private_key)

def base64url(value)
  Base64.urlsafe_encode64(value, padding: false)
end

def token
  now = Time.now.to_i
  header = { alg: "ES256", kid: ENV.fetch("APP_STORE_CONNECT_KEY_ID"), typ: "JWT" }
  payload = {
    iss: ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"),
    iat: now - 5,
    exp: now + 15 * 60,
    aud: "appstoreconnect-v1"
  }
  unsigned = [header, payload].map { |part| base64url(JSON.generate(part)) }.join(".")
  key = OpenSSL::PKey.read(File.binread(ENV.fetch("APP_STORE_CONNECT_API_KEY_PATH")))
  decoded = OpenSSL::ASN1.decode(key.sign(OpenSSL::Digest::SHA256.new, unsigned))
  r = decoded.value.fetch(0).value.to_i
  s = decoded.value.fetch(1).value.to_i
  raw_signature = [
    r.to_s(16).rjust(64, "0") + s.to_s(16).rjust(64, "0")
  ].pack("H*")
  "#{unsigned}.#{base64url(raw_signature)}"
end

def safe_error_values(body, key, pattern)
  parsed = JSON.parse(body)
  return [] unless parsed.is_a?(Hash)

  errors = parsed.fetch("errors", [])
  return [] unless errors.is_a?(Array)

  errors.filter_map do |error|
    next unless error.is_a?(Hash)

    value = error[key]
    next unless value.is_a?(String)

    normalized = value.gsub(/[[:cntrl:]]/, " ").strip[0, 160]
    normalized if normalized.match?(pattern)
  end.uniq.first(8)
rescue JSON::ParserError
  []
end

def api_uri(path_or_url, query)
  uri = if path_or_url.start_with?("/")
          URI("#{API_ROOT}#{path_or_url}")
        else
          URI(path_or_url)
        end
  unless uri.scheme == "https" && uri.host == "api.appstoreconnect.apple.com" &&
         uri.port == 443 && uri.path.start_with?("/v1/") && uri.userinfo.nil?
    raise AppStoreConnectInvariantError.new(
      stage: "pagination",
      reason_code: "UNSAFE_NEXT_LINK",
      message: "App Store Connect pagination link is unsafe"
    )
  end
  uri.query = URI.encode_www_form(query) if query
  uri
rescue URI::InvalidURIError
  raise AppStoreConnectInvariantError.new(
    stage: "pagination",
    reason_code: "INVALID_NEXT_LINK",
    message: "App Store Connect pagination link is invalid"
  )
end

def request(path_or_url, query = nil, stage:, allow_not_found: false)
  uri = api_uri(path_or_url, query)
  call = Net::HTTP::Get.new(uri)
  call["Authorization"] = "Bearer #{token}"
  call["Accept"] = "application/json"
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.open_timeout = 15
    http.read_timeout = 30
    http.request(call)
  end
  return nil if allow_not_found && response.code == "404"

  unless response.is_a?(Net::HTTPSuccess)
    raise AppStoreConnectQueryError.new(
      stage: stage,
      http_status: response.code.to_i,
      error_codes: safe_error_values(response.body, "code", /\A[A-Za-z0-9._-]{1,160}\z/),
      error_titles: safe_error_values(response.body, "title", /\A[^\r\n]{1,160}\z/)
    )
  end
  if response.body.bytesize > MAXIMUM_RESPONSE_BYTES
    raise AppStoreConnectInvariantError.new(
      stage: stage,
      reason_code: "RESPONSE_TOO_LARGE",
      message: "App Store Connect API response exceeds 512 KiB"
    )
  end

  JSON.parse(response.body)
rescue AppStoreConnectQueryError, AppStoreConnectInvariantError
  raise
rescue StandardError
  raise AppStoreConnectQueryError.new(
    stage: stage,
    http_status: nil,
    error_codes: ["TRANSPORT_ERROR"],
    error_titles: []
  )
end

def only_resource(response, name, stage)
  data = response.fetch("data")
  resources = data.is_a?(Array) ? data : [data]
  unless resources.length == 1
    raise AppStoreConnectInvariantError.new(
      stage: stage,
      reason_code: "RESOURCE_CARDINALITY",
      message: "Expected exactly one #{name}, found #{resources.length}"
    )
  end

  resources.first
end

def paginated_resources(path, query, stage:, maximum_pages:)
  resources = []
  next_url = path
  next_query = query
  page = 0
  while next_url
    page += 1
    if page > maximum_pages
      raise AppStoreConnectInvariantError.new(
        stage: stage,
        reason_code: "PAGINATION_LIMIT",
        message: "App Store Connect pagination exceeds the safety limit"
      )
    end
    response = request(next_url, next_query, stage: stage)
    data = response.fetch("data")
    unless data.is_a?(Array)
      raise AppStoreConnectInvariantError.new(
        stage: stage,
        reason_code: "INVALID_COLLECTION",
        message: "App Store Connect collection data must be an array"
      )
    end
    resources.concat(data)
    next_url = response.fetch("links", {}).fetch("next", nil)
    next_query = nil
  end
  resources
end

def diagnostic_classification(http_status)
  case http_status
  when 401 then "authentication"
  when 403 then "authorization"
  when 429 then "rate_limit"
  when 500..599 then "service_transient"
  when nil then "transport"
  else "request"
  end
end

def write_diagnostic(path, payload)
  return if path.to_s.strip.empty?

  File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
    file.write(JSON.pretty_generate(payload))
  end
end

begin
  bundle_id = options.fetch(:bundle_id)
  marketing_version = options.fetch(:marketing_version)
  build_number = options.fetch(:build_number)
  external_group = options.fetch(:external_group)

  app = only_resource(
    request("/apps", { "filter[bundleId]" => bundle_id, "limit" => "2" }, stage: "app"),
    "app",
    "app"
  )
  build = only_resource(
    request(
      "/builds",
      {
        "filter[app]" => app.fetch("id"),
        "filter[version]" => build_number,
        "sort" => "-uploadedDate",
        "limit" => "2"
      },
      stage: "build"
    ),
    "build",
    "build"
  )
  pre_release = only_resource(
    request("/builds/#{build.fetch('id')}/preReleaseVersion", stage: "pre_release_version"),
    "pre-release version",
    "pre_release_version"
  )
  beta_detail = only_resource(
    request("/builds/#{build.fetch('id')}/buildBetaDetail", stage: "build_beta_detail"),
    "build beta detail",
    "build_beta_detail"
  )
  review_response = request(
    "/builds/#{build.fetch('id')}/betaAppReviewSubmission",
    nil,
    stage: "beta_review_submission",
    allow_not_found: true
  )
  review = review_response && only_resource(review_response, "beta review submission", "beta_review_submission")
  groups_response = request(
    "/betaGroups",
    {
      "filter[app]" => app.fetch("id"),
      "filter[name]" => external_group,
      "fields[betaGroups]" => "name,isInternalGroup,publicLinkEnabled,publicLink",
      "limit" => "2"
    },
    stage: "beta_group"
  )
  groups = groups_response.fetch("data")
  unless groups.is_a?(Array)
    raise AppStoreConnectInvariantError.new(
      stage: "beta_group",
      reason_code: "INVALID_COLLECTION",
      message: "betaGroups data must be an array"
    )
  end

  matching_groups = groups.select do |group|
    group.fetch("attributes", {}).fetch("name", nil) == external_group
  end
  unless matching_groups.length == 1
    raise AppStoreConnectInvariantError.new(
      stage: "beta_group",
      reason_code: "FIXED_GROUP_CARDINALITY",
      message: "Expected the fixed external group exactly once"
    )
  end

  matching_group = matching_groups.first
  group_attributes = matching_group.fetch("attributes")
  unless group_attributes.fetch("isInternalGroup") == false
    raise AppStoreConnectInvariantError.new(
      stage: "beta_group",
      reason_code: "FIXED_GROUP_IS_INTERNAL",
      message: "Fixed TestFlight group must be external"
    )
  end

  group_id = matching_group.fetch("id")
  unless group_id.match?(/\A[A-Za-z0-9-]{1,128}\z/)
    raise AppStoreConnectInvariantError.new(
      stage: "beta_group",
      reason_code: "UNSAFE_GROUP_ID",
      message: "Fixed TestFlight group ID is unsafe"
    )
  end
  group_builds = paginated_resources(
    "/betaGroups/#{group_id}/builds",
    { "fields[builds]" => "version", "limit" => "200" },
    stage: "beta_group_builds",
    maximum_pages: MAXIMUM_GROUP_BUILD_PAGES
  )
  unless group_builds.count { |item| item.fetch("id", nil) == build.fetch("id") } == 1
    raise AppStoreConnectInvariantError.new(
      stage: "beta_group_builds",
      reason_code: "EXACT_BUILD_NOT_ASSIGNED",
      message: "Exact build is not assigned to the fixed TestFlight group"
    )
  end

  build_attributes = build.fetch("attributes")
  detail_attributes = beta_detail.fetch("attributes")
  unless build_attributes.fetch("version") == build_number &&
         pre_release.fetch("attributes").fetch("version") == marketing_version
    raise AppStoreConnectInvariantError.new(
      stage: "candidate_identity",
      reason_code: "CANDIDATE_IDENTITY_MISMATCH",
      message: "App Store Connect build identity does not match the immutable candidate"
    )
  end
  external_state = detail_attributes.fetch("externalBuildState")
  review_state = review&.fetch("attributes", {})&.fetch("betaReviewState", nil)
  public_link = group_attributes.fetch("publicLink", nil)
  public_link_enabled = group_attributes.fetch("publicLinkEnabled")
  unless public_link == options.fetch(:public_link)
    raise AppStoreConnectInvariantError.new(
      stage: "beta_group",
      reason_code: "PUBLIC_LINK_MISMATCH",
      message: "Fixed TestFlight public link does not match App Store Connect"
    )
  end
  testing = external_state == "IN_BETA_TESTING" && review_state == "APPROVED" && public_link_enabled

  result = {
    schemaVersion: 1,
    bundleId: bundle_id,
    marketingVersion: pre_release.fetch("attributes").fetch("version"),
    buildNumber: build_attributes.fetch("version"),
    appId: app.fetch("id"),
    buildId: build.fetch("id"),
    processingState: build_attributes.fetch("processingState"),
    expired: build_attributes.fetch("expired"),
    betaReviewState: review_state || "NOT_SUBMITTED",
    externalBuildState: external_state,
    testing: testing,
    externalGroups: groups.map { |group| group.fetch("attributes", {}).fetch("name", nil) }.compact,
    publicLink: public_link.to_s
  }

  puts JSON.pretty_generate(result)
rescue AppStoreConnectQueryError => e
  write_diagnostic(
    options[:diagnostic],
    {
      schemaVersion: 1,
      service: "appStoreConnect",
      safe: true,
      status: "failed",
      stage: e.stage,
      classification: diagnostic_classification(e.http_status),
      httpStatus: e.http_status,
      errorCodes: e.error_codes,
      errorTitles: e.error_titles
    }
  )
  suffix = e.http_status ? " with HTTP #{e.http_status}" : ""
  warn "App Store Connect status query failed at #{e.stage}#{suffix}"
  exit 1
rescue AppStoreConnectInvariantError => e
  write_diagnostic(
    options[:diagnostic],
    {
      schemaVersion: 1,
      service: "appStoreConnect",
      safe: true,
      status: "failed",
      stage: e.stage,
      classification: "configuration",
      httpStatus: nil,
      reasonCode: e.reason_code,
      errorCodes: [],
      errorTitles: []
    }
  )
  warn "App Store Connect status query failed at #{e.stage}: #{e.reason_code}"
  exit 1
rescue StandardError
  write_diagnostic(
    options[:diagnostic],
    {
      schemaVersion: 1,
      service: "appStoreConnect",
      safe: true,
      status: "failed",
      stage: "response_validation",
      classification: "response",
      httpStatus: nil,
      reasonCode: "UNEXPECTED_RESPONSE",
      errorCodes: [],
      errorTitles: []
    }
  )
  warn "App Store Connect status query failed at response_validation: UNEXPECTED_RESPONSE"
  exit 1
end
