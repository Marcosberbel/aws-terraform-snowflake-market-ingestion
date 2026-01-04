param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("dev","pre","pro")]
  [string]$Env,

  [string]$Region = "eu-south-2"
)

. "$PSScriptRoot/common.ps1"
Require-Command "aws"
Require-Command "terraform"

$root    = Get-RepoRoot
$envDir  = Join-Path $root "infra\environments\$Env"
$tfvars  = Join-Path $envDir "$Env.tfvars"
$backend = Join-Path $envDir "backend.tf"

Assert-TfvarsMatchesEnv $Env $tfvars
Assert-BackendMatchesEnv $Env $backend

$profile = Get-ProfileFromTfvars $tfvars "terraform-$Env"
Use-AwsProfile $profile $Region

Set-Location $envDir
terraform init
terraform destroy -var-file="$Env.tfvars"
