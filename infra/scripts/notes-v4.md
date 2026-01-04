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
```

---

## MFA + AssumeRole “modo empresa” (base → base-mfa → terraform-dev/pre/pro)

Este repo soporta un flujo profesional con MFA + roles por entorno:

- **`base`**: credenciales *largas* (AccessKey/Secret) de un usuario/rol “bootstrap” (ej. `terraform-bootstrap`).
- **`base-mfa`**: credenciales *temporales* (AccessKey/Secret + **SessionToken**) obtenidas con MFA. Estas son las que deben usarse como `source_profile`.
- **`terraform-dev/pre/pro`**: perfiles que hacen `AssumeRole` a `TerraformRoleDEV/PRE/PRO` usando `source_profile = base-mfa`.

### Config recomendada (`~/.aws/config`)

```ini
[default]
region = eu-south-2

[profile base]
region = eu-south-2

[profile base-mfa]
region = eu-south-2

[profile terraform-dev]
role_arn = arn:aws:iam::248650134365:role/TerraformRoleDEV
source_profile = base-mfa
region = eu-south-2

[profile terraform-pre]
role_arn = arn:aws:iam::248650134365:role/TerraformRolePRE
source_profile = base-mfa
region = eu-south-2

[profile terraform-pro]
role_arn = arn:aws:iam::248650134365:role/TerraformRolePRO
source_profile = base-mfa
region = eu-south-2
```

### Flujo diario (1 vez por sesión / 12h)

1) Renovar credenciales temporales MFA (perfil `base-mfa`):
```powershell
.\scripts\refresh-base-mfa.ps1 -DurationSeconds 43200
```

2) Verificar:
```powershell
aws sts get-caller-identity --profile base-mfa
aws sts get-caller-identity --profile terraform-dev
```

> Nota: `aws configure list --profile base-mfa` **no suele mostrar** `aws_session_token`, aunque exista. Usa `aws sts get-caller-identity` para verificar.

---

## Fix crítico (eu-south-2): `InvalidClientTokenId` con `base-mfa`

Si te pasa esto:

```powershell
aws sts get-caller-identity --profile base-mfa
# -> InvalidClientTokenId (en eu-south-2)
```

pero **sí funciona** si fuerzas región, por ejemplo:

```powershell
aws sts get-caller-identity --profile base-mfa --region us-east-1
```

Entonces tu cuenta probablemente tiene `GlobalEndpointTokenVersion = 1` (STS v1 tokens).

### Solución definitiva (1 vez)

1) Comprobar:
```powershell
aws iam get-account-summary --profile base --query "SummaryMap.GlobalEndpointTokenVersion" --output text
```

2) Si devuelve `1`, cambiar a v2:
```powershell
aws iam set-security-token-service-preferences --global-endpoint-token-version v2Token --profile base
```

3) Verificar que ya es `2`:
```powershell
aws iam get-account-summary --profile base --query "SummaryMap.GlobalEndpointTokenVersion" --output text
```

4) Regenerar `base-mfa` (muy importante: el token anterior era “v1”):
```powershell
.\scripts\refresh-base-mfa.ps1 -DurationSeconds 43200
```

Después de esto, `base-mfa` debería funcionar en `eu-south-2` sin forzar región.

---

## Script `refresh-base-mfa.ps1` (qué hace)

Este script:

1) Obtiene el `MFA Serial` del usuario (ej. `arn:aws:iam::<account>:mfa/terraform-bootstrap`).
2) Te pide **el código MFA (6 dígitos)** (lo sacas de tu app del móvil).
3) Llama a STS `get-session-token` para obtener credenciales temporales.
4) Escribe/actualiza la sección `[base-mfa]` en `~/.aws/credentials`.

### Errores típicos

- **`Unable to parse config file: ~/.aws/credentials`**
  - El INI quedó corrupto (token con saltos, secciones duplicadas, etc.).
  - Solución: limpiar/reparar el archivo y regenerar `base-mfa`.

- **`InvalidClientTokenId`**
  - Si `--region us-east-1` funciona y `eu-south-2` falla: aplica el fix de **v2Token** arriba.
  - Ejecutar `aws iam set-security-token-service-preferences --global-endpoint-token-version v2Token --profile base`
   
---

## Seguridad (muy importante)

- **Nunca pegues AccessKey/Secret/SessionToken en chats o repos.**
- Si alguna vez se expusieron, **rota** (desactiva y crea nuevas) las access keys del usuario `terraform-bootstrap` en IAM.
- Ideal empresa: usar SSO/OIDC; para este proyecto está OK usar user+MFA por ser demo, pero mantén rotación y mínimos permisos.

