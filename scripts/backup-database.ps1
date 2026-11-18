$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root 'backend/.env'
if (!(Test-Path $envFile)) { throw "backend/.env not found." }

$values = @{}
foreach ($line in Get-Content $envFile) {
  if ($line -match '^\s*([A-Z_]+)=(.*)$') { $values[$matches[1]] = $matches[2].Trim('"') }
}
$url = $values['DATABASE_URL']
if (!$url) { throw 'DATABASE_URL is missing from backend/.env' }

$backupDir = Join-Path $root 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$file = Join-Path $backupDir "estate-$stamp.dump"

$env:PGPASSWORD = $values['POSTGRES_PASSWORD'] ?? ''
& pg_dump --dbname=$url --format=custom --file=$file --no-owner --no-privileges 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'pg_dump failed. Install PostgreSQL client tools or check DATABASE_URL.' }

Write-Host "Database backup written to $file"
