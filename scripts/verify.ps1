$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot "backend\src"
$frontendRoot = Join-Path $projectRoot "frontend"

Push-Location $backendRoot
$env:DJANGO_DATABASE_ENGINE = "sqlite"
python manage.py check
python manage.py test core modeling
Pop-Location

Push-Location $frontendRoot
npm test
npm run build
Pop-Location
