param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$ClientId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ClientId)) {
    return
}

$target = "MicrosoftStoreCli:user=$ClientId"
$null = @(& cmdkey.exe "/delete:$target" 2>&1)
if ($LASTEXITCODE -eq 0) {
    return
}

$listOutput = @(& cmdkey.exe "/list:$target" 2>&1)
if ($LASTEXITCODE -ne 0 -or
    $null -ne ($listOutput | Where-Object { $_.TrimEnd().EndsWith($target) })) {
    throw 'Failed to remove Microsoft Store CLI credentials.'
}
