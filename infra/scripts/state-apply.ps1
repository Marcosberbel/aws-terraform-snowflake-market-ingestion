param(
  [string]$Profile = "terraform-dev",
  [string]$Region  = "eu-south-2"
)

. "$PSScriptRoot/common.ps1"
Require-Command "aws"
Require-Command "terraform"

$root     = Get-RepoRoot
$stateDir = Join-Path $root "infra\state"
$tfvars   = Join-Path $stateDir "state.auto.tfvars"

Use-AwsProfile $Profile $Region

Ensure-File $tfvars "Crea el fichero copiando el ejemplo:`n  copy infra\state\state.auto.tfvars.example.auto.tfvars infra\state\state.auto.tfvars`nY edítalo si aplica."

Set-Location $stateDir
terraform init
terraform fmt -recursive
terraform validate
terraform plan  -var-file="state.auto.tfvars"
terraform apply -var-file="state.auto.tfvars"
