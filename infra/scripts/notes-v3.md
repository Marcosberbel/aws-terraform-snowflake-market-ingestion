# Scripts PowerShell — Terraform (dev / pre / pro)

Estos scripts automatizan la ejecución de Terraform por entorno, evitando errores típicos:
- entrar en la carpeta equivocada
- usar un `AWS_PROFILE` incorrecto
- olvidar `fmt/validate` antes de plan/apply

El repo soporta **dos formas “pro” de manejar credenciales/perfiles** (las dos son válidas). Abajo te indico cuál usar en local y cuál en CI.

---

## Requisitos previos

1) PowerShell permitir scripts (una vez):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

2) Tener instalados y en PATH:
- `aws` (AWS CLI)
- `terraform`

3) Tener perfiles AWS configurados (assume-role):
- `terraform-dev`
- `terraform-pre`
- `terraform-pro`

Verificación rápida (ejemplo):
```powershell
aws sts get-caller-identity --profile terraform-dev
```

---

## Backend S3 por entorno (recordatorio clave)

El **bucket de state** NO va en `*.tfvars`. Lo decide **`backend.tf`** dentro de cada entorno:

- `infra/environments/dev/backend.tf` → bucket dev + `key = "dev/terraform.tfstate"`
- `infra/environments/pre/backend.tf` → bucket pre + `key = "pre/terraform.tfstate"`
- `infra/environments/pro/backend.tf` → bucket pro + `key = "pro/terraform.tfstate"`

El perfil/rol solo aporta permisos; el backend decide el bucket.

---

## Credenciales / perfiles: 2 modos soportados

En tu `provider.tf` tienes:

```hcl
provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null
}
```

### Modo A — “Empresa/CI-friendly” (recomendado en CI)
**El perfil NO va en Terraform**. Lo controla el runtime (scripts/CI) vía variables de entorno u OIDC.

- En `dev.tfvars/pre.tfvars/pro.tfvars` puedes dejar `aws_profile = ""` (o no usar esa variable).
- Terraform usa la cadena estándar de credenciales (env/OIDC/shared config).

✅ Ventajas: CI compatible (OIDC), evita duplicidades, más portable.  
⚠️ Contras: menos “autoexplicativo” en tfvars.

### Modo B — “Autodescriptivo” (recomendado en local)
**El perfil se declara en `*.tfvars`** y el provider lo usa.

Ejemplo `dev.tfvars`:
```hcl
aws_profile = "terraform-dev"
environment = "dev"
region      = "eu-south-2"
```
✅ Ventajas: súper explícito (entrevista), fácil de entender.  
⚠️ Contras: en CI normalmente no hay perfiles (mejor Modo A).

> En tu caso actual, quieres usar este Modo B en local: perfecto.

---

## Cómo funcionan los scripts (con tu preferencia: `aws_profile` en tfvars)

- Para `env-plan/apply/destroy/output`:
  - leen `infra/environments/<env>/<env>.tfvars`
  - validan que `environment` y `aws_profile` coinciden con `-Env <env>`
  - (opcional) exportan `AWS_PROFILE` solo para validar identidad con `aws sts get-caller-identity`

- Para `state-apply`:
  - **no hay tfvars por entorno** (es bootstrap del backend)
  - se ejecuta con `-Env dev|pre|pro` y usa el perfil `terraform-<env>` (uniforme con el resto)

---

## Scripts disponibles

### `set-env.ps1`
Prepara el entorno (exporta perfil y valida con STS).
```powershell
.\scripts\set-env.ps1 -Env dev
```

### `state-apply.ps1`
Crea el backend remoto (buckets state dev/pre/pro + Dynamo locks). Se ejecuta **una vez** al inicio.
```powershell
.\scripts\state-apply.ps1 -Env dev
```
> Aunque se ejecute con `-Env dev`, crea los 3 buckets (dev/pre/pro) y la tabla locks.

### `env-plan.ps1`
Plan de un entorno.
```powershell
.\scripts\env-plan.ps1 -Env dev
```

### `env-apply.ps1`
Apply de un entorno.
```powershell
.\scripts\env-apply.ps1 -Env dev
```

### `env-destroy.ps1`
Destroy de un entorno (no toca `infra/state`).
```powershell
.\scripts\env-destroy.ps1 -Env dev
```

### `env-output.ps1`
Outputs del entorno.
```powershell
.\scripts\env-output.ps1 -Env dev
```

---

## Flujo recomendado (orden correcto)

1) Backend remoto (una vez):
```powershell
.\scripts\state-apply.ps1 -Env dev
```

2) Desplegar DEV:
```powershell
.\scripts\env-plan.ps1  -Env dev
.\scripts\env-apply.ps1 -Env dev
```

3) Promocionar a PRE:
```powershell
.\scripts\env-plan.ps1  -Env pre
.\scripts\env-apply.ps1 -Env pre
```

4) Promocionar a PRO:
```powershell
.\scripts\env-plan.ps1  -Env pro
.\scripts\env-apply.ps1 -Env pro
```

---

## Troubleshooting rápido

### “profile could not be found”
```powershell
aws configure list-profiles
```

### “AccessDenied” / permisos
Comprueba identidad del perfil:
```powershell
aws sts get-caller-identity --profile terraform-dev
```

### Terraform init/apply falla
```powershell
terraform -v
aws --version
