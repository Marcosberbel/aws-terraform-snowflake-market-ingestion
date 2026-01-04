# Scripts PowerShell — Terraform (dev / pre / pro)

Estos scripts automatizan la ejecución de Terraform por entorno, evitando errores típicos:
- entrar en la carpeta equivocada
- usar un `AWS_PROFILE` incorrecto
- olvidar `fmt/validate` antes de plan/apply

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
- También si borras el backend y quieres recrearlo (no recomendado sin motivo).

**Requisitos**
- Debe existir: `infra/state/state.auto.tfvars`
  - Se crea copiando el ejemplo:
    ```powershell
    copy infra\state\state.auto.tfvars.example.auto.tfvars infra\state\state.auto.tfvars
    ```

**Ejemplo**
```powershell
.\scripts\state-apply.ps1 -Env dev
```
> Se usa `-Env dev` solo para elegir con qué perfil ejecutar (puedes usar pre/pro también).

---

### 4) `env-plan.ps1`
**Qué hace**
- Ejecuta `plan` en un entorno concreto:
  - `terraform init`
  - `terraform fmt -recursive`
  - `terraform validate`
  - `terraform plan -var-file="<env>.tfvars"`

**Cuándo usarlo**
- Antes de un `apply` (recomendado siempre).
- Para revisar qué cambios se van a aplicar.

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

**Cuándo usarlo**
- Para desplegar/actualizar recursos en `dev`, luego `pre`, luego `pro`.

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

**Cuándo usarlo**
- Para limpiar un entorno (ej: DEV) sin afectar a PRE/PRO.

**⚠️ Importante**
- NO destruye el backend remoto (`infra/state`).
- Destruir `pro` suele ser mala idea; úsalo con cuidado.

**Ejemplo**
```powershell
.\scripts\env-destroy.ps1 -Env dev
```

---

### 7) `env-output.ps1`
**Qué hace**
- Muestra los outputs de Terraform del entorno:
  - `terraform output`

**Cuándo usarlo**
- Para ver endpoints (API), nombres de recursos, ARNs, etc.

**Ejemplo**
```powershell
.\scripts\env-output.ps1 -Env dev
```

---

## Flujo recomendado (orden correcto)

### 1) Backend remoto (una vez)
```powershell
.\scripts\state-apply.ps1 -Env dev
```

### 2) Desplegar DEV
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

## Troubleshooting rápido

### Error: “profile could not be found”
- No existe el perfil en `~/.aws/config` o `~/.aws/credentials`.
- Verifica con:
```powershell
aws configure list-profiles
```

### Error: Terraform no puede hacer init/apply
- Verifica herramientas:
```powershell
terraform -v
aws --version
```

### Error: permisos
- Revisa que el perfil `terraform-<env>` realmente asume el rol correcto:
```powershell
aws sts get-caller-identity --profile terraform-dev
```

---

## Nota sobre ejecución desde cualquier carpeta
Los scripts calculan el repo root basándose en `scripts/` y luego hacen `Set-Location` a la carpeta del entorno correspondiente.  
Por eso es recomendable ejecutarlos desde la raíz del repo o desde cualquier subcarpeta dentro del repo.
