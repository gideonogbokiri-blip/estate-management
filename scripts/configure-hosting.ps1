$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$client = Join-Path $root 'client'
$snippet = '<script>if (![''localhost'',''127.0.0.1''].includes(window.location.hostname)) { document.documentElement.setAttribute(''data-api-base'', window.location.origin + ''/api/v1''); }</script>'
$dirs = @('web', 'admin', 'onboarding', 'platform', 'security', 'properties', 'landlord-live', 'map', 'landlord', 'join-estate', 'resident-review', 'tenant-rent')

foreach ($dir in $dirs) {
  $index = Join-Path $client "build/$dir/index.html"
  if (!(Test-Path $index)) { continue }
  $html = Get-Content $index -Raw
  $html = [regex]::Replace($html, '<script>[^<]*data-api-base[^<]*</script>\s*', '')
  if ($html -notlike '*data-api-base*') {
    $html = $html -replace '</head>', "$snippet`n</head>"
  }
  Set-Content -Path $index -Value $html -Encoding utf8 -NoNewline
}
Write-Host 'Hosting configuration applied to all built bundles.'
