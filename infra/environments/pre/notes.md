# Entorno pre

Este directorio **no define recursos directos**, solo **llama a módulos** desde `infra/modules/*`.

## Orden de ejecución
1) Asegúrate de haber creado el backend (una sola vez):
```powershell
cd infra\state
terraform init
terraform apply -var-file="state.auto.tfvars"
```

2) Inicializa este entorno:
```powershell
cd infra\environments\pre
terraform init
```

3) Calidad:
```powershell
terraform fmt -recursive
terraform validate
tflint --init
tflint
```

4) Plan y apply:
```powershell
terraform plan  -var-file="pre.tfvars"
terraform apply -var-file="pre.tfvars"
```

5) Destroy del entorno (no toca otros entornos):
```powershell
terraform destroy -var-file="pre.tfvars"
```

## Backend
- Bucket S3 de state: 1 por entorno (dev/pre/pro)
- Key: `pre/terraform.tfstate`
- Locks: DynamoDB común
