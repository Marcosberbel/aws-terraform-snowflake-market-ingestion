# infra/state (backend de Terraform)

## Qué crea
- **1 bucket S3 de state por entorno** (`dev`, `pre`, `pro`)
- **1 tabla DynamoDB** para locking de estado (común)

> Motivo: Terraform no puede usar backend S3 si el bucket no existe. Por eso este root usa backend **local** y solo crea el backend remoto.

## Comandos
```powershell
cd infra\state
copy state.auto.tfvars.example.auto.tfvars state.auto.tfvars
terraform init
terraform plan
terraform apply
```

## Outputs
- `state_buckets`: mapa env -> bucket
- `lock_table_name`: nombre de tabla DynamoDB

Luego esos nombres se usan en `infra/environments/*/backend.tf`.

## Destruir
No se recomienda destruir el backend a menudo (pierdes los states).
Si lo necesitas:
```powershell
terraform destroy
```
