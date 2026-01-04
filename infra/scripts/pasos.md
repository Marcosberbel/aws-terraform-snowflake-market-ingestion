# pasos.md — Orden y comandos para desplegar (dev / pre / pro)

> Objetivo: que sepas **qué ejecutar** y **en qué orden**, sin liarte con perfiles / backends / tfvars.

## 0) Prerrequisitos (una vez)

En PowerShell:

```powershell
terraform -v
aws --version
tflint --version
```

Si Windows te bloquea scripts:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 1) Perfiles AWS (día a día)

### 1.1 Refrescar MFA (si usas `base-mfa`)
Cuando el token caduque, refresca:

```powershell
.\infra\scripts
efresh-base-mfa.ps1
```

Validación rápida (recomendado con STS global):

```powershell
aws sts get-caller-identity --profile base-mfa --region us-east-1
```

### 1.2 Validar roles por entorno
```powershell
aws sts get-caller-identity --profile terraform-dev
aws sts get-caller-identity --profile terraform-pre
aws sts get-caller-identity --profile terraform-pro
```

---

## 2) Bootstrap del backend remoto (S3 state + DynamoDB locks)

Esto **solo crea el backend** (buckets state y tablas locks).  
Se ejecuta **una vez** (o si cambias nombres/lista de entornos).

Desde la raíz del repo:

```powershell
.\infra\scripts\state-apply.ps1 -Env dev
```

> Nota: aunque pongas `-Env dev`, el root `infra/state` crea lo definido en `environments = ["dev","pre","pro"]`.
> `-Env dev` solo decide con qué perfil se ejecuta el bootstrap.

---

## 3) Inicializar (o reconfigurar) cada entorno

Obligatorio:
- primera vez
- o si has cambiado el `backend.tf` (bucket/tabla/key)

```powershell
cd .\infra\environments\dev
terraform init -reconfigure

cd ..\pre
terraform init -reconfigure

cd ..\pro
terraform init -reconfigure

cd ..\..
```

---

## 4) Flujo “pro” por entorno: PLAN -> APPLY

### DEV
```powershell
.\infra\scripts\env-plan.ps1  -Env dev
.\infra\scripts\env-apply.ps1 -Env dev
```

### PRE
```powershell
.\infra\scripts\env-plan.ps1  -Env pre
.\infra\scripts\env-apply.ps1 -Env pre
```

### PRO
```powershell
.\infra\scripts\env-plan.ps1  -Env pro
.\infra\scripts\env-apply.ps1 -Env pro
```

---

## 5) Ver outputs (endpoint API, nombres, etc.)

```powershell
.\infra\scripts\env-output.ps1 -Env dev
.\infra\scripts\env-output.ps1 -Env pre
.\infra\scripts\env-output.ps1 -Env pro
```

---

## 6) Destroy de un entorno (sin tocar los otros)

```powershell
.\infra\scripts\env-destroy.ps1 -Env dev
```

> **No destruyas `infra/state`** salvo que quieras borrar los buckets/tablas de backend.

---

## 7) Validación rápida de tfvars (evitar errores como “pre con terraform-dev”)

Tu repo usa:
- `infra/environments/dev/dev.tfvars`
- `infra/environments/pre/pre.tfvars`
- `infra/environments/pro/pro.tfvars`

Asegura que cada uno tenga **environment** y **aws_profile** correctos:

- `dev.tfvars` → `environment="dev"`, `aws_profile="terraform-dev"`
- `pre.tfvars` → `environment="pre"`, `aws_profile="terraform-pre"`
- `pro.tfvars` → `environment="pro"`, `aws_profile="terraform-pro"`

Comando para auditar los 3 de golpe:

```powershell
Select-String -Path .\infra\environments\*\*.tfvars -Pattern "environment|aws_profile"
```

---

## 8) Recomendación (para no romperte nunca con copy/paste)

Tienes dos enfoques válidos:

### Opción A (explícito): mantener `aws_profile` en tfvars
✅ Muy claro/auditable  
⚠️ Si copias un tfvars y no cambias el profile, el script fallará (bien).

### Opción B (automático): dejar `aws_profile = ""` en todos los tfvars
Y que el script mande el perfil con `AWS_PROFILE`.

- En `dev/pre/pro.tfvars` deja:
  ```hcl
  aws_profile = ""
  ```
- Tu provider ya lo soporta:
  ```hcl
  profile = var.aws_profile != "" ? var.aws_profile : null
  ```

✅ Cero riesgo de “pre con terraform-dev”.

Elige una y sé consistente.
