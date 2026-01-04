# notes.md — Scripts de despliegue (infra/scripts)

Este documento describe **qué hace cada script** y **cuándo usarlo**.

## Convención del repo

- Roots por entorno:
  - `infra/environments/dev`
  - `infra/environments/pre`
  - `infra/environments/pro`
- tfvars por entorno:
  - `infra/environments/dev/dev.tfvars`
  - `infra/environments/pre/pre.tfvars`
  - `infra/environments/pro/pro.tfvars`
- Perfiles AWS:
  - `terraform-dev`, `terraform-pre`, `terraform-pro`
- (Opcional con MFA) perfil temporal:
  - `base-mfa` (credenciales temporales en `~/.aws/credentials`)

---

## common.ps1

Utilidades comunes:
- Detecta la raíz del repo (si `infra/scripts` cuelga dentro de `infra/`)
- Verifica comandos (aws/terraform)
- Setea `AWS_PROFILE` / `AWS_REGION`
- Valida ficheros necesarios
- (Opcional) valida consistencia de `aws_profile` dentro de `*.tfvars`

> Si ves caracteres raros (emojis) en errores, cambia los `throw` a texto sin emojis.

---

## refresh-base-mfa.ps1

**Cuándo**: cuando caduca el token MFA.  
**Qué hace**: llama a STS `GetSessionToken` usando tu usuario base + MFA y escribe el perfil `base-mfa` en `~/.aws/credentials`.

Uso:
```powershell
.\infra\scripts
efresh-base-mfa.ps1
```

Validación recomendada:
```powershell
aws sts get-caller-identity --profile base-mfa --region us-east-1
```

---

## state-apply.ps1

**Cuándo**: 1 vez al inicio (o cuando cambies nombres/lista de entornos).  
**Qué hace**: aplica Terraform en `infra/state` para crear:
- buckets S3 de state por entorno
- tablas DynamoDB de locks (según tu diseño)

Uso:
```powershell
.\infra\scripts\state-apply.ps1 -Env dev
```

Notas:
- Aunque pases `-Env dev`, el root `infra/state` crea todo lo que esté en `environments = [...]`.
- Si cambiaste `backend.tf` de los entornos, luego ejecuta `terraform init -reconfigure` en cada uno.

---

## env-plan.ps1

**Qué hace**: ejecuta `terraform init`, `fmt`, `validate` y `plan` en el entorno elegido, usando su tfvars.

Uso:
```powershell
.\infra\scripts\env-plan.ps1  -Env dev
.\infra\scripts\env-plan.ps1  -Env pre
.\infra\scripts\env-plan.ps1  -Env pro
```

Lee:
- `infra/environments/<env>/<env>.tfvars`

---

## env-apply.ps1

**Qué hace**: ejecuta `terraform init`, `fmt`, `validate` y `apply` en el entorno elegido.

Uso:
```powershell
.\infra\scripts\env-apply.ps1 -Env dev
.\infra\scripts\env-apply.ps1 -Env pre
.\infra\scripts\env-apply.ps1 -Env pro
```

### Validación pro: tfvars vs env
Si tu script valida que `aws_profile` dentro de tfvars coincide con `terraform-<env>`, y te sale algo como:

- `tfvars inconsistente: aws_profile='terraform-dev' pero se esperaba 'terraform-pre'`

**Solución**:
- Corrige `infra/environments/pre/pre.tfvars` a `aws_profile = "terraform-pre"`, etc.
- O adopta la estrategia “automática”: `aws_profile = ""` en todos los tfvars y que mande el script.

Auditar todos los tfvars:
```powershell
Select-String -Path .\infra\environments\*\*.tfvars -Pattern "environment|aws_profile"
```

---

## env-output.ps1

**Qué hace**: muestra outputs del entorno (API endpoint, nombres, etc.)

Uso:
```powershell
.\infra\scripts\env-output.ps1 -Env dev
```

---

## env-destroy.ps1

**Qué hace**: destruye SOLO los recursos del entorno indicado (no toca otros entornos).

Uso:
```powershell
.\infra\scripts\env-destroy.ps1 -Env dev
```

---

## Orden recomendado (empresa)

1) (si MFA) `refresh-base-mfa`
2) `state-apply` (solo al inicio)
3) `terraform init -reconfigure` en dev/pre/pro (si backend cambió o primera vez)
4) DEV: `plan` -> `apply`
5) Validación DEV (outputs / endpoint)
6) PRE: `plan` -> `apply`
7) PRO: `plan` -> `apply`
