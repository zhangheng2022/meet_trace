[CmdletBinding()]
param(
    [string]$Repository = '',
    [string]$TestFlightExternalGroup = '',
    [string]$TestFlightPublicLink = '',
    [string]$PartnerCenterFlightId = '',
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required.'
}
if ([string]::IsNullOrWhiteSpace($Repository)) {
    $Repository = (gh repo view --json nameWithOwner --jq .nameWithOwner).Trim()
}
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw "Invalid repository: $Repository"
}

$environments = @(
    'android-alpha',
    'testflight',
    'windows-alpha',
    'microsoft-store',
    'github-release',
    'windows-store-validation'
)

Write-Host "Repository: $Repository"
Write-Host 'This bootstrap removes all environment wait timers and required reviewers.'
Write-Host 'Workflow identity checks and master branch protection remain the release authorization boundary.'
if (-not [string]::IsNullOrWhiteSpace($TestFlightExternalGroup) -and
    $TestFlightExternalGroup.Length -gt 128) {
    throw 'TestFlightExternalGroup must be 128 characters or fewer.'
}
if (-not [string]::IsNullOrWhiteSpace($TestFlightPublicLink) -and
    $TestFlightPublicLink -notmatch '^https://testflight\.apple\.com/join/[A-Za-z0-9]+/?$') {
    throw 'TestFlightPublicLink must be a stable TestFlight public link.'
}
if (-not [string]::IsNullOrWhiteSpace($PartnerCenterFlightId) -and
    $PartnerCenterFlightId -notmatch '^[A-Za-z0-9._-]{1,128}$') {
    throw 'PartnerCenterFlightId has an invalid format.'
}
if (-not $Apply) {
    Write-Host ''
    Write-Host 'Dry run only. Re-run with -Apply after this workflow change is merged to master.'
    Write-Host "Environments: $($environments -join ', ')"
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($TestFlightExternalGroup)) {
    gh variable set TESTFLIGHT_EXTERNAL_GROUP --repo $Repository `
        --env testflight --body $TestFlightExternalGroup
    gh variable set TESTFLIGHT_EXTERNAL_GROUP --repo $Repository `
        --env github-release --body $TestFlightExternalGroup
}
if (-not [string]::IsNullOrWhiteSpace($TestFlightPublicLink)) {
    gh variable set TESTFLIGHT_PUBLIC_LINK --repo $Repository `
        --env testflight --body $TestFlightPublicLink
    gh variable set TESTFLIGHT_PUBLIC_LINK --repo $Repository `
        --env github-release --body $TestFlightPublicLink
}
if (-not [string]::IsNullOrWhiteSpace($PartnerCenterFlightId)) {
    gh variable set PARTNER_CENTER_FLIGHT_ID --repo $Repository `
        --env microsoft-store --body $PartnerCenterFlightId
    gh variable set PARTNER_CENTER_FLIGHT_ID --repo $Repository `
        --env github-release --body $PartnerCenterFlightId
}

$requiredSecrets = @{
    'testflight' = @(
        'APP_STORE_CONNECT_KEY_ID',
        'APP_STORE_CONNECT_ISSUER_ID',
        'APP_STORE_CONNECT_API_KEY_P8_BASE64'
    )
    'microsoft-store' = @(
        'PARTNER_CENTER_TENANT_ID',
        'PARTNER_CENTER_SELLER_ID',
        'PARTNER_CENTER_CLIENT_ID',
        'PARTNER_CENTER_CLIENT_SECRET'
    )
    'github-release' = @('APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64')
}
foreach ($environment in $requiredSecrets.Keys) {
    $configured = @(
        gh secret list --repo $Repository --env $environment `
            --json name --jq '.[].name'
    )
    foreach ($name in $requiredSecrets[$environment]) {
        if ($configured -notcontains $name) {
            throw "Missing environment secret $environment/$name. Configure it with gh secret set before releasing."
        }
    }
}

$testFlightVariables = @(
    gh variable list --repo $Repository --env testflight `
        --json name --jq '.[].name'
)
foreach ($name in @('TESTFLIGHT_EXTERNAL_GROUP', 'TESTFLIGHT_PUBLIC_LINK')) {
    if ($testFlightVariables -notcontains $name) {
        throw "Missing environment variable testflight/$name."
    }
}
$storeVariables = @(
    gh variable list --repo $Repository --env microsoft-store `
        --json name --jq '.[].name'
)
if ($storeVariables -notcontains 'PARTNER_CENTER_FLIGHT_ID') {
    throw 'Missing environment variable microsoft-store/PARTNER_CENTER_FLIGHT_ID.'
}
$releaseVariables = @(
    gh variable list --repo $Repository --env github-release `
        --json name --jq '.[].name'
)
foreach ($name in @(
        'TESTFLIGHT_EXTERNAL_GROUP',
        'TESTFLIGHT_PUBLIC_LINK',
        'PARTNER_CENTER_FLIGHT_ID')) {
    if ($releaseVariables -notcontains $name) {
        throw "Missing environment variable github-release/$name."
    }
}

$legacyReleaseSecrets = @(
    gh secret list --repo $Repository --env github-release `
        --json name --jq '.[].name'
)
foreach ($name in @(
        'PARTNER_CENTER_TENANT_ID',
        'PARTNER_CENTER_SELLER_ID',
        'PARTNER_CENTER_CLIENT_ID',
        'PARTNER_CENTER_CLIENT_SECRET')) {
    if ($legacyReleaseSecrets -contains $name) {
        gh secret delete $name --repo $Repository --env github-release
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove legacy github-release secret: $name"
        }
        Write-Host "Removed redundant Partner Center secret from github-release: $name"
    }
}

# Removing reviewers is intentionally the final mutation. A missing credential or
# fixed variable therefore leaves the existing release protections untouched.
foreach ($environment in $environments) {
    $encodedEnvironment = [Uri]::EscapeDataString($environment)
    $currentJson = gh api "repos/$Repository/environments/$encodedEnvironment" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($currentJson -join "`n"))) {
        $deploymentPolicy = @{
            protected_branches = $true
            custom_branch_policies = $false
        }
    } else {
        $current = ($currentJson -join "`n") | ConvertFrom-Json
        $deploymentPolicy = $current.deployment_branch_policy
        if ($null -eq $deploymentPolicy) {
            $deploymentPolicy = @{
                protected_branches = $true
                custom_branch_policies = $false
            }
        }
    }
    $payload = @{
        wait_timer = 0
        prevent_self_review = $false
        reviewers = @()
        deployment_branch_policy = $deploymentPolicy
    } | ConvertTo-Json -Depth 6
    $payload | gh api "repos/$Repository/environments/$encodedEnvironment" `
        --method PUT --input - | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure environment: $environment"
    }
    Write-Host "Configured environment without manual approval: $environment"
}

Write-Host 'Release automation bootstrap completed. No required reviewer remains.'
