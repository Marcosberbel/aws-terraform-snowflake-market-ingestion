param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("dev","pre","pro")]
  [string]$Env,

  [string]$Region = "eu-south-2"
)

. "$PSScriptRoot/common.ps1"
Require-Command "aws"

$root   = Get-RepoRoot
$envDir = Join-Path $root "infra\environments\$Env"
$tfvars = Join-Path $envDir "$Env.tfvars"

Assert-TfvarsMatchesEnv $Env $tfvars

$profile = Get-ProfileFromTfvars $tfvars "terraform-$Env"
Use-AwsProfile $profile $Region

Write-Host "✅ Entorno preparado: $Env (perfil $profile)" -ForegroundColor Green
