# aws-terraform-snowflake-market-ingestion

Repositorio “producto” para entrevistas: **IaC profesional en AWS con Terraform**, multi-entorno (dev/pre/pro) en **la misma cuenta** y región por defecto **eu-south-2 (Madrid)**.

## Qué incluye (coste ~0 si destruyes)
- Backend remoto de Terraform por entorno (**1 bucket S3 de state por entorno**) + **DynamoDB lock**.
- Módulos por servicio (carpeta por módulo) con:
  - `main.tf`, `variables.tf`, `outputs.tf`, `notes.md`
- Red **VPC** segura “mínimo coste” (sin NAT Gateway) + subnets públicas (2 AZ).
- S3 “storage” (no state) con cifrado, bloqueo público, versionado opcional.
- DynamoDB (PAY_PER_REQUEST) con cifrado (por defecto) y tags.
- Lambda “API” (esqueleto) + IAM mínimo (sin secretos en repo).
- API Gateway (HTTP API) para exponer Lambda.
- CloudWatch Logs (log group y retención configurable).
- EventBridge (regla + target para ejecuciones programadas).
- GitHub Actions (CI) para `fmt`, `validate`, `tflint`.

> Nota coste: lo único que puede costar si lo dejas encendido es el uso real de API Gateway/Lambda/DynamoDB (tráfico) y almacenamiento S3. VPC sin NAT es 0€.

## Ruta rápida (local)
1) Crear backend (una vez):
```powershell
cd infra\state
terraform init
terraform apply -var-file="state.auto.tfvars"
```

2) Aplicar DEV:
```powershell
cd ..\environments\dev
terraform init
terraform plan  -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

3) Destruir DEV:
```powershell
terraform destroy -var-file="dev.tfvars"
```

## Carpetas
- `infra/state` -> crea buckets de state (dev/pre/pro) + tabla DynamoDB locks.
- `infra/environments/*` -> root por entorno (invocan módulos).
- `infra/modules/*` -> módulos por servicio.

