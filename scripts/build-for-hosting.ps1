$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$client = Join-Path $root 'client'

$targets = @(
  @{ Target = 'lib/main.dart';                    Out = 'web' },
  @{ Target = 'lib/admin_main.dart';               Out = 'admin' },
  @{ Target = 'lib/onboarding_main.dart';          Out = 'onboarding' },
  @{ Target = 'lib/platform_admin_main.dart';      Out = 'platform' },
  @{ Target = 'lib/security_main.dart';            Out = 'security' },
  @{ Target = 'lib/property_register_main.dart';   Out = 'properties' },
  @{ Target = 'lib/landlord_portal_main.dart';     Out = 'landlord-live' },
  @{ Target = 'lib/estate_map_main.dart';          Out = 'map' },
  @{ Target = 'lib/landlord_main.dart';            Out = 'landlord' },
  @{ Target = 'lib/resident_join_main.dart';       Out = 'join-estate' },
  @{ Target = 'lib/resident_review_main.dart';     Out = 'resident-review' },
  @{ Target = 'lib/tenant_rent_main.dart';         Out = 'tenant-rent' }
)

Push-Location $client
try {
  foreach ($item in $targets) {
    Write-Host "Building $($item.Out) ..."
    flutter build web --release --target $item.Target --output "build/$($item.Out)" --base-href "/$($item.Out)/"
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $($item.Out)" }
  }

  # One bundle set works on any host: the API address is resolved at runtime.
  $snippet = '<script>if (![''localhost'',''127.0.0.1''].includes(window.location.hostname)) { document.documentElement.setAttribute(''data-api-base'', window.location.origin + ''/api/v1''); }</script>'
  foreach ($item in $targets) {
    $index = Join-Path $client "build/$($item.Out)/index.html"
    if (Test-Path $index) {
      $html = Get-Content $index -Raw
      if ($html -notlike '*data-api-base*') {
        $html = $html -replace '</head>', "$snippet`n</head>"
        Set-Content -Path $index -Value $html -Encoding utf8 -NoNewline
      }
    }
  }
  Write-Host 'All web bundles built and configured for runtime API resolution.'

  # Static pages are not Flutter bundles: keep them in sync on every rebuild.
  $loginDir = Join-Path $client 'build/login'
  New-Item -ItemType Directory -Force -Path $loginDir | Out-Null
  Copy-Item (Join-Path $client 'login.html') (Join-Path $loginDir 'index.html') -Force
  Copy-Item (Join-Path $client 'assets/images/onboarding_background.jpg') (Join-Path $loginDir 'family-background.jpg') -Force
  Copy-Item (Join-Path $client 'preview.html') (Join-Path $client 'build/index.html') -Force
  $demoDir = Join-Path $client 'build/demo'
  New-Item -ItemType Directory -Force -Path $demoDir | Out-Null
  Copy-Item (Join-Path $client 'demo.html') (Join-Path $demoDir 'index.html') -Force
  Write-Host 'Homepage, sign-in page, demo notes and family background copied.'
}
finally {
  Pop-Location
}
