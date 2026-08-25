# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "time"
require "uri"

API_ROOT = "https://api.appstoreconnect.apple.com/v1"

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

def request(path, query = nil, allow_not_found: false)
  uri = URI("#{API_ROOT}#{path}")
  uri.query = URI.encode_www_form(query) if query
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
    raise "App Store Connect API #{path} failed with HTTP #{response.code}"
  end
  raise "App Store Connect API response exceeds 512 KiB" if response.body.bytesize > 512 * 1024

  JSON.parse(response.body)
end

def only_resource(response, name)
  data = response.fetch("data")
  resources = data.is_a?(Array) ? data : [data]
  raise "Expected exactly one #{name}, found #{resources.length}" unless resources.length == 1

  resources.first
end

bundle_id = options.fetch(:bundle_id)
marketing_version = options.fetch(:marketing_version)
build_number = options.fetch(:build_number)
external_group = options.fetch(:external_group)

app = only_resource(
  request("/apps", { "filter[bundleId]" => bundle_id, "limit" => "2" }),
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
    }
  ),
  "build"
)
pre_release = only_resource(
  request("/builds/#{build.fetch('id')}/preReleaseVersion"),
  "pre-release version"
)
beta_detail = only_resource(
  request("/builds/#{build.fetch('id')}/buildBetaDetail"),
  "build beta detail"
)
review_response = request(
  "/builds/#{build.fetch('id')}/betaAppReviewSubmission",
  nil,
  allow_not_found: true
)
review = review_response && only_resource(review_response, "beta review submission")
groups_response = request("/builds/#{build.fetch('id')}/betaGroups", { "limit" => "200" })
groups = groups_response.fetch("data")
raise "betaGroups data must be an array" unless groups.is_a?(Array)

matching_groups = groups.select do |group|
  group.fetch("attributes", {}).fetch("name", nil) == external_group
end
raise "Expected the fixed external group exactly once" unless matching_groups.length == 1

group_attributes = matching_groups.first.fetch("attributes")
build_attributes = build.fetch("attributes")
detail_attributes = beta_detail.fetch("attributes")
external_state = detail_attributes.fetch("externalBuildState")
review_state = review&.fetch("attributes", {})&.fetch("betaReviewState", nil)
public_link = group_attributes.fetch("publicLink", nil)
public_link_enabled = group_attributes.fetch("isPublicLinkEnabled", !public_link.to_s.empty?)
raise "Fixed TestFlight public link does not match App Store Connect" unless public_link == options.fetch(:public_link)
testing = ["READY_FOR_EXTERNAL_TESTING", "TESTING"].include?(external_state) &&
          review_state == "APPROVED" && public_link_enabled

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
