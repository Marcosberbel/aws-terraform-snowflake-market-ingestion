Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  # infra/scripts -> repo root (dos niveles arriba)
  return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "No encuentro el comando '$name' en PATH. Instálalo o reinicia la terminal."
  }
}

function Ensure-File($path, $hint) {
  if (-not (Test-Path $path)) {
    throw "Falta el fichero: $path`n$hint"
  }
}

function Read-TfvarsValue([string]$tfvarsPath, [string]$key) {
  # Parse simple: key = "value"  OR key = value
  $content = Get-Content $tfvarsPath -Raw

  $m1 = [regex]::Match($content, "(?m)^\s*$key\s*=\s*""([^""]*)""\s*$")
  if ($m1.Success) { return $m1.Groups[1].Value }

  $m2 = [regex]::Match($content, "(?m)^\s*$key\s*=\s*([^\r\n#]+)\s*$")
  if ($m2.Success) { return $m2.Groups[1].Value.Trim() }

  return $null
}

function Get-ProfileFromTfvars([string]$tfvarsPath, [string]$fallbackProfile = "") {
  $p = Read-TfvarsValue $tfvarsPath "aws_profile"
  if ([string]::IsNullOrWhiteSpace($p)) { return $fallbackProfile }
  return $p
}

function Use-AwsProfile(
  [string]$profile,
  [string]$region,
  [string]$expectedAccountId = "248650134365"
) {
  if (-not [string]::IsNullOrWhiteSpace($profile)) {
    $env:AWS_PROFILE = $profile
  }
  $env:AWS_REGION = $region
  $env:AWS_DEFAULT_REGION = $region

  Write-Host "AWS_PROFILE=$($env:AWS_PROFILE) | AWS_REGION=$($env:AWS_REGION)"

  # Guardrail cuenta
  $id = (& aws sts get-caller-identity | ConvertFrom-Json)
  if ($id.Account -ne $expectedAccountId) {
    throw "🚫 Cuenta incorrecta. Estás en $($id.Account) pero se esperaba $expectedAccountId. Abortando."
  }

  Write-Host "✅ Credenciales OK | Cuenta: $($id.Account) | Arn: $($id.Arn)" -ForegroundColor Green
}

function Assert-TfvarsMatchesEnv([string]$envName, [string]$tfvarsPath) {
  Ensure-File $tfvarsPath "No encuentro $tfvarsPath"

  $envVar = Read-TfvarsValue $tfvarsPath "environment"
  if (-not [string]::IsNullOrWhiteSpace($envVar) -and $envVar -ne $envName) {
    throw "🚫 tfvars inconsistente: environment='$envVar' pero estás ejecutando -Env $envName"
  }

  $prof = Read-TfvarsValue $tfvarsPath "aws_profile"
  $expectedProfile = "terraform-$envName"
  if (-not [string]::IsNullOrWhiteSpace($prof) -and $prof -ne $expectedProfile) {
    throw "🚫 tfvars inconsistente: aws_profile='$prof' pero se esperaba '$expectedProfile' para -Env $envName"
  }

  Write-Host "✅ tfvars OK: environment='$envVar' | aws_profile='$prof'" -ForegroundColor Green
}

function Assert-BackendMatchesEnv([string]$envName, [string]$backendPath) {
  Ensure-File $backendPath "Debe existir backend.tf en infra/environments/$envName/backend.tf"

  $content = Get-Content $backendPath -Raw

  $bucket = ([regex]::Match($content, 'bucket\s*=\s*"([^"]+)"')).Groups[1].Value
  $key    = ([regex]::Match($content, 'key\s*=\s*"([^"]+)"')).Groups[1].Value

  if ([string]::IsNullOrWhiteSpace($bucket) -or [string]::IsNullOrWhiteSpace($key)) {
    throw "backend.tf no tiene bucket/key bien definidos. Revisa: $backendPath"
  }

  if (-not ($key -like "$envName/*")) {
    throw "🚫 backend.tf inválido: key='$key' no empieza por '$envName/'. Debe ser '$envName/terraform.tfstate'."
  }

  # Aviso suave si el bucket no contiene el env (tú sí lo tienes: ...-dev-...)
  if ($bucket -notmatch "(^|[-_])$envName($|[-_])") {
    Write-Host "⚠️ Aviso: el bucket '$bucket' no parece contener '$envName' en el nombre. Revísalo." -ForegroundColor Yellow
  }

  Write-Host "✅ Backend OK: bucket='$bucket' | key='$key'" -ForegroundColor Green
}
