param(
  [string]$BaseProfile = "base",
  [string]$MfaProfile  = "base-mfa",
  [string]$UserName    = "terraform-bootstrap",
  [string]$Region      = "eu-south-2",
  [int]$DurationSeconds = 86400
)

$ErrorActionPreference = "Stop"

# ---- helpers: escribir INI sin usar "aws configure set" (evita truncado) ----
function Upsert-CredentialsProfile {
  param(
    [string]$ProfileName,
    [hashtable]$Kv
  )

  $awsDir = Join-Path $HOME ".aws"
  if (-not (Test-Path $awsDir)) { New-Item -ItemType Directory -Path $awsDir | Out-Null }

  $credPath = Join-Path $awsDir "credentials"
  if (-not (Test-Path $credPath)) { New-Item -ItemType File -Path $credPath | Out-Null }

  $lines = Get-Content $credPath -ErrorAction SilentlyContinue
  if (-not $lines) { $lines = @() }

  $start = $null
  $end   = $null

  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*\[$([regex]::Escape($ProfileName))\]\s*$") {
      $start = $i
      $j = $i + 1
      while ($j -lt $lines.Count -and $lines[$j] -notmatch "^\s*\[.*\]\s*$") { $j++ }
      $end = $j
      break
    }
  }

  $newSection = @()
  $newSection += "[$ProfileName]"
  foreach ($k in $Kv.Keys) {
    $newSection += "$k = $($Kv[$k])"
  }

  if ($start -ne $null) {
    # Reemplaza sección existente
    $before = @()
    if ($start -gt 0) { $before = $lines[0..($start-1)] }

    $after = @()
    if ($end -lt $lines.Count) { $after = $lines[$end..($lines.Count-1)] }

    $lines = @($before + $newSection + @("") + $after)
  } else {
    # Añade al final
    if ($lines.Count -gt 0 -and $lines[-1].Trim() -ne "") { $lines += "" }
    $lines += $newSection
    $lines += ""
  }

  Set-Content -Path $credPath -Value $lines -Encoding ASCII
  return $credPath
}

# 1) Obtiene el ARN del dispositivo MFA
$mfa = aws iam list-mfa-devices --user-name $UserName --profile $BaseProfile | ConvertFrom-Json
if (-not $mfa.MFADevices -or $mfa.MFADevices.Count -eq 0) {
  throw "No hay dispositivo MFA asociado a '$UserName'. Asigna MFA en IAM primero."
}
$serial = $mfa.MFADevices[0].SerialNumber
Write-Host "MFA Serial: $serial"

# 2) Pide el código MFA
$code = Read-Host "Introduce el codigo MFA (6 dígitos) para $UserName"

# 3) Pide credenciales temporales
$resp = aws sts get-session-token `
  --serial-number $serial `
  --token-code $code `
  --duration-seconds $DurationSeconds `
  --profile $BaseProfile | ConvertFrom-Json

$creds = $resp.Credentials
if (-not $creds.AccessKeyId) { throw "No se obtuvieron credenciales. Revisa el MFA." }

# IMPORTANTE: aplanar token por si AWS devuelve saltos de línea
$ak      = $creds.AccessKeyId.Trim()
$sk      = $creds.SecretAccessKey.Trim()
$session = ($creds.SessionToken -replace "\s","")   # quita CR/LF/espacios/tabs

# 4) Escribe el perfil base-mfa sin truncar y sin saltos
$credPath = Upsert-CredentialsProfile -ProfileName $MfaProfile -Kv @{
  "aws_access_key_id"     = $ak
  "aws_secret_access_key" = $sk
  "aws_session_token"     = $session
}

Write-Host "✅ Perfil '$MfaProfile' actualizado en $credPath" -ForegroundColor Green
Write-Host "Expira: $($creds.Expiration)" -ForegroundColor Yellow
