## Bootstrap IAM Roles (dev/pre/pro)

Crea roles en la MISMA cuenta AWS (1 account) para separar permisos por entorno.
Se ejecuta con el perfil `base`. Luego usarás perfiles `terraform-dev/pre/pro` como assume-role.

### 1) Preparar tfvars
Copia el ejemplo:
- bootstrap.auto.tfvars.example -> bootstrap.auto.tfvars
Rellena `base_principal_arn` con el ARN de tu user/rol base.

### 2) Ejecutar
En PowerShell:

$env:AWS_PROFILE="base"
cd infra\bootstrap\iam-roles
terraform init
terraform apply

### 3) Ver outputs
Terraform te devuelve los ARNs de:
- TerraformRoleDEV
- TerraformRolePRE
- TerraformRolePRO

Con esos ARNs configuras tus perfiles `terraform-dev/pre/pro` en ~/.aws/config.
