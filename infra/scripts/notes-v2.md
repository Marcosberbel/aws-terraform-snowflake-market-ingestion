# Scripts PowerShell — Terraform (dev / pre / pro)

Estos scripts automatizan la ejecución de Terraform por entorno, evitando errores típicos:
- entrar en la carpeta equivocada
- usar un `AWS_PROFILE` incorrecto
- olvidar `fmt/validate` antes de plan/apply

Además, el repo soporta **dos formas “pro” de manejar credenciales/perfiles** (las dos son válidas).

---

## Requisitos previos

1) PowerShell permitir scripts (una vez):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

2) Tener instalados y en PATH:
- `aws` (AWS CLI)
- `terraform`

3) Tener perfiles AWS configurados:
- `terraform-dev`
- `terraform-pre`
- `terraform-pro`

Verificación rápida (ejemplo):
```powershell
aws sts get-caller-identity --profile terraform-dev
```

> Nota: Los scripts se encargan de posicionarse en la carpeta correcta (`infra/state` o `infra/environments/<env>`).  
> Puedes ejecutarlos desde la raíz del repo.

---

## Credenciales / perfiles: 2 modos soportados

En tu Terraform tienes esto en el provider:

```hcl
provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null
}
```

Eso permite dos modos **sin cambiar código** (solo cambiando cómo ejecutas):

### Modo A — “Empresa/CI-friendly” (recomendado)
**El perfil NO va en Terraform**, lo controla el runtime (scripts / CI) vía variables de entorno.

- En `dev.tfvars` puedes **dejar `aws_profile = ""`** (o incluso eliminarlo si quieres).
- El script setea: `AWS_PROFILE=terraform-dev`
- Terraform usa el *credential chain* estándar (env / shared config / assume-role / OIDC).

✅ Ventajas:
- Es lo estándar en empresa y CI (GitHub Actions suele usar OIDC, no profiles).
- Evita conflictos entre `AWS_PROFILE` y `var.aws_profile`.
- Más portable.

**Ejemplo DEV**
```powershell
$env:AWS_PROFILE="terraform-dev"
cd infra\environments\dev
terraform init
terraform apply -var-file="dev.tfvars" -var="aws_profile="
```
> Nota: el `-var="aws_profile="` fuerza que el provider no use `profile` aunque exista en tfvars.

**Con scripts (recomendado)**
- Los scripts pueden exportar `AWS_PROFILE=terraform-<env>` y además forzar `aws_profile` vacío (ver “Uso recomendado”).

---

### Modo B — “Autodescriptivo” (perfil declarado en tfvars)
**El perfil se define en `*.tfvars`** y el provider lo usa (tu setup actual).

- `dev.tfvars` contiene: `aws_profile = "terraform-dev"`
- En local, funciona genial porque se entiende “de un vistazo” qué perfil usa cada entorno.

✅ Ventajas:
- Muy explícito (en entrevistas queda claro).
- Menos dependencia de “qué variable exportaste” en la terminal.

⚠️ Contras:
- En CI suele ser menos compatible si no hay profiles.
- Puede ser peligroso si ejecutas con un `AWS_PROFILE` distinto al del tfvars (por eso conviene guardrail).

**Ejemplo DEV**
```powershell
cd infra\environments\dev
terraform init
terraform apply -var-file="dev.tfvars"
```

---

## Recomendación práctica (lo mejor de ambos mundos)
- **Local (tú solo):** puedes usar **Modo B** (muy explícito) **pero** con scripts que validen coherencia.
- **CI/CD (GitHub Actions):** usa **Modo A** (sin profiles en tfvars), normalmente con OIDC.

---

## Scripts disponibles

### 1) `common.ps1` (interno)
**Qué hace**
- Funciones compartidas por el resto: validación de comandos, `AWS_PROFILE`, comprobación de ficheros y cálculo del repo root.

**Cómo se usa**
- No se ejecuta directamente; lo importan los demás scripts.

---

### 2) `set-env.ps1`
**Qué hace**
- Setea y valida el entorno AWS:
  - exporta `AWS_PROFILE=terraform-<env>`
  - exporta `AWS_REGION` / `AWS_DEFAULT_REGION`
  - valida credenciales con `aws sts get-caller-identity`

**Cuándo usarlo**
- Cuando quieras “dejar preparado” un entorno para ejecutar comandos manuales (aws/terraform) fuera de scripts.

**Ejemplo**
```powershell
.\scripts\set-env.ps1 -Env dev
```

---

### 3) `state-apply.ps1`
**Qué hace**
- Crea el backend remoto de Terraform:
  - buckets S3 de state por entorno (dev/pre/pro)
  - tabla DynamoDB para locks
- Ejecuta:
  - `terraform init`
  - `terraform fmt -recursive`
  - `terraform validate`
  - `terraform plan/apply` usando `infra/state/state.auto.tfvars`

**Cuándo usarlo**
- **Solo una vez al inicio**, antes de desplegar `infra/environments/*`.

**Requisitos**
- Debe existir: `infra/state/state.auto.tfvars`


**Ejemplo**
```powershell
.\scripts\state-apply.ps1 -Env dev
```

---

### 4) `env-plan.ps1`
**Qué hace**
- Ejecuta `plan` en un entorno concreto:
  - `terraform init`
  - `terraform fmt -recursive`
  - `terraform validate`
  - `terraform plan -var-file="<env>.tfvars"`

**Ejemplo**
```powershell
.\scripts\env-plan.ps1 -Env dev
```

---

### 5) `env-apply.ps1`
**Qué hace**
- Aplica infraestructura en un entorno concreto:
  - `terraform init`
  - `terraform fmt -recursive`
  - `terraform validate`
  - `terraform apply -var-file="<env>.tfvars"`

**Ejemplo**
```powershell
.\scripts\env-apply.ps1 -Env dev
```

---

### 6) `env-destroy.ps1`
**Qué hace**
- Destruye la infraestructura de un entorno:
  - `terraform init`
  - `terraform destroy -var-file="<env>.tfvars"`

**Ejemplo**
```powershell
.\scripts\env-destroy.ps1 -Env dev
```

---

### 7) `env-output.ps1`
**Qué hace**
- Muestra los outputs de Terraform del entorno:
  - `terraform output`

**Ejemplo**
```powershell
.\scripts\env-output.ps1 -Env dev
```

---

## Uso recomendado (orden correcto)

### 1) Backend remoto (una vez)
```powershell
.\scripts\state-apply.ps1 -Env dev
```

### 2) Desplegar DEV (plan + apply)
```powershell
.\scripts\env-plan.ps1  -Env dev
.\scripts\env-apply.ps1 -Env dev
```

### 3) Promocionar a PRE
```powershell
.\scripts\env-plan.ps1  -Env pre
.\scripts\env-apply.ps1 -Env pre
```

### 4) Promocionar a PRO
```powershell
.\scripts\env-plan.ps1  -Env pro
.\scripts\env-apply.ps1 -Env pro
```

---

## Nota importante sobre backend y buckets por entorno
- El bucket de state **NO va en `*.tfvars`**.
- El bucket de state lo decide **`backend.tf`** dentro de cada carpeta de entorno:
  - `infra/environments/dev/backend.tf` → bucket dev + `key = "dev/terraform.tfstate"`
  - `infra/environments/pre/backend.tf` → bucket pre + `key = "pre/terraform.tfstate"`
  - `infra/environments/pro/backend.tf` → bucket pro + `key = "pro/terraform.tfstate"`

El perfil (role) solo aporta permisos; el backend decide el bucket.

---

## Troubleshooting rápido

### Error: “profile could not be found”
- No existe el perfil en `~/.aws/config` o `~/.aws/credentials`.
- Verifica con:
```powershell
aws configure list-profiles
```

### Error: permisos / cuenta equivocada
```powershell
aws sts get-caller-identity --profile terraform-dev
```

### Terraform init/apply falla
```powershell
terraform -v
aws --version
