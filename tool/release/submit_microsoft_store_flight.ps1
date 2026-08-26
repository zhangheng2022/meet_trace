param(
  [Parameter(Mandatory = $true)][string]$CandidatePath,
  [Parameter(Mandatory = $true)][string]$ManifestPath,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [Parameter(Mandatory = $true)][string]$ProductId,
  [Parameter(Mandatory = $true)][string]$FlightId,
  [Parameter(Mandatory = $true)][string]$ReleaseId,
  [Parameter(Mandatory = $true)][string]$CandidateSha,
  [Parameter(Mandatory = $true)][long]$SourceRunId,
  [Parameter(Mandatory = $true)][string]$TenantId,
  [Parameter(Mandatory = $true)][string]$SellerId,
  [Parameter(Mandatory = $true)][string]$ClientId,
  [Parameter(Mandatory = $true)][string]$ClientSecret
)

$ErrorActionPreference = 'Stop'

if ($ProductId -cne '9PHHSJMWK06G' -or
    $FlightId -notmatch '^[A-Za-z0-9._-]{1,128}$' -or
    $ReleaseId -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*$' -or
    $CandidateSha -notmatch '^[0-9a-f]{40}$' -or
    $SourceRunId -le 0) {
  throw 'Invalid immutable Microsoft Store Flight identity.'
}
foreach ($value in @($TenantId, $SellerId, $ClientId, $ClientSecret)) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw 'Microsoft Store credentials must be non-empty.'
  }
}
if (-not (Test-Path -LiteralPath $CandidatePath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
  throw 'Microsoft Store candidate or manifest is missing.'
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$artifactName = [string]$manifest.artifact.name
$packageVersion = [string]$manifest.packageVersion
$expectedArtifactName = "meettrace-$ReleaseId-windows-store-x64.msix"
$actualDigest = (Get-FileHash -LiteralPath $CandidatePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($manifest.schemaVersion -ne 1 -or
    $manifest.releaseId -cne $ReleaseId -or
    $manifest.commitSha -cne $CandidateSha -or
    $manifest.distribution -cne 'microsoftStore' -or
    $manifest.storeId -cne $ProductId -or
    $artifactName -cne $expectedArtifactName -or
    $packageVersion -notmatch '^1\.0\.[1-9][0-9]*\.0$' -or
    $manifest.artifact.storeSubmissionCandidate -ne $true -or
    $manifest.artifact.publiclyInstallable -ne $false -or
    [string]$manifest.artifact.sha256 -cne $actualDigest -or
    (Split-Path -Leaf $CandidatePath) -cne $artifactName) {
  throw 'Microsoft Store candidate identity or digest changed.'
}

msstore reconfigure `
  --tenantId $TenantId `
  --sellerId $SellerId `
  --clientId $ClientId `
  --clientSecret $ClientSecret
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to configure Microsoft Store CLI credentials.'
}
msstore settings --enableTelemetry false
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to disable Microsoft Store CLI telemetry.'
}

$token = Invoke-RestMethod -Method Post `
  -Uri "https://login.microsoftonline.com/$TenantId/oauth2/token" `
  -ContentType 'application/x-www-form-urlencoded' `
  -Body @{
    grant_type = 'client_credentials'
    client_id = $ClientId
    client_secret = $ClientSecret
    resource = 'https://manage.devcenter.microsoft.com'
  }
if ([string]::IsNullOrWhiteSpace([string]$token.access_token)) {
  throw 'Microsoft Store submission API token is missing.'
}
$headers = @{ Authorization = "Bearer $($token.access_token)" }
$baseUri = "https://manage.devcenter.microsoft.com/v1.0/my/applications/$ProductId/flights/$FlightId"

function Get-FlightSubmission([string]$SubmissionId) {
  if ($SubmissionId -notmatch '^[1-9][0-9]*$') {
    throw 'Microsoft Store Flight submission ID is invalid.'
  }
  $resource = Invoke-RestMethod -Method Get `
    -Uri "$baseUri/submissions/$SubmissionId" -Headers $headers
  $status = Invoke-RestMethod -Method Get `
    -Uri "$baseUri/submissions/$SubmissionId/status" -Headers $headers
  if ([string]$resource.id -cne $SubmissionId) {
    throw 'Microsoft Store Flight submission response ID changed.'
  }
  return [pscustomobject]@{
    Id = [string]$resource.id
    Status = ([string]$status.status).ToLowerInvariant()
    Packages = @($resource.flightPackages)
    Errors = @($status.statusDetails.errors)
  }
}

function Test-ExactCandidate($Submission) {
  $matches = @($Submission.Packages | Where-Object {
      [string]$_.fileName -ceq $artifactName -and
      [string]$_.version -ceq $packageVersion
    })
  return $matches.Count -eq 1 -and $Submission.Packages.Count -eq 1
}

function Test-RecoverableCandidate($Submission) {
  if (Test-ExactCandidate $Submission) {
    return $true
  }
  $matches = @($Submission.Errors | Where-Object {
      [string]$_.code -ceq 'InvalidParameterValue' -and
      [string]$_.details -match [regex]::Escape($packageVersion)
    })
  return $Submission.Packages.Count -eq 0 -and $matches.Count -eq 1
}

$activeStatuses = @(
  'commitstarted', 'preprocessing', 'certification', 'release',
  'pendingpublication', 'publishing', 'published'
)
$recoverableStatuses = @('pendingcommit', 'commitfailed')
$state = $null
$submissionId = $null
$flight = Invoke-RestMethod -Method Get -Uri $baseUri -Headers $headers
$pendingId = [string]$flight.pendingFlightSubmission.id

if (-not [string]::IsNullOrWhiteSpace($pendingId)) {
  $pending = Get-FlightSubmission $pendingId
  if ((Test-ExactCandidate $pending) -and
      $activeStatuses -contains $pending.Status) {
    $submissionId = $pending.Id
    $state = 'reused'
  } elseif (($recoverableStatuses -contains $pending.Status) -and
      (Test-RecoverableCandidate $pending)) {
    Invoke-RestMethod -Method Delete `
      -Uri "$baseUri/submissions/$pendingId" -Headers $headers
    $state = 'recovered'
  } elseif (-not (Test-ExactCandidate $pending)) {
    throw 'Pending Package Flight submission belongs to a different candidate.'
  } else {
    throw "Package Flight submission is blocked: $($pending.Status)"
  }
} else {
  $publishedId = [string]$flight.lastPublishedFlightSubmission.id
  if (-not [string]::IsNullOrWhiteSpace($publishedId)) {
    $published = Get-FlightSubmission $publishedId
    if ((Test-ExactCandidate $published) -and
        $published.Status -eq 'published') {
      $submissionId = $published.Id
      $state = 'reused'
    }
  }
}

if ([string]::IsNullOrWhiteSpace($submissionId)) {
  $inputDirectory = Split-Path -Parent $CandidatePath
  msstore publish $CandidatePath `
    --inputDirectory $inputDirectory `
    --appId $ProductId `
    --flightId $FlightId `
    --uploadTimeout 900
  if ($LASTEXITCODE -ne 0) {
    throw 'Microsoft Store Package Flight submission failed.'
  }
  $flight = Invoke-RestMethod -Method Get -Uri $baseUri -Headers $headers
  $submissionId = [string]$flight.pendingFlightSubmission.id
  if ([string]::IsNullOrWhiteSpace($submissionId)) {
    $submissionId = [string]$flight.lastPublishedFlightSubmission.id
  }
  $submitted = Get-FlightSubmission $submissionId
  if (-not (Test-ExactCandidate $submitted) -or
      $activeStatuses -notcontains $submitted.Status) {
    throw 'Submitted Package Flight could not be bound to the immutable candidate.'
  }
  if ($state -ne 'recovered') {
    $state = 'submitted'
  }
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
[ordered]@{
  schemaVersion = 1
  distribution = 'microsoftStoreFlight'
  state = $state
  productId = $ProductId
  flightId = $FlightId
  releaseId = $ReleaseId
  candidateCommitSha = $CandidateSha
  sourceRunId = $SourceRunId
  reconciliationRunId = [long]$env:GITHUB_RUN_ID
  submissionId = $submissionId
  submittedAtUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  package = [ordered]@{
    fileName = $artifactName
    version = $packageVersion
    architecture = 'x64'
    candidateSha256 = [string]$manifest.artifact.sha256
  }
} | ConvertTo-Json -Depth 6 | Set-Content `
  -LiteralPath $OutputPath -Encoding utf8
