# Entorno pro

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
cd infra\environments\pro
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
terraform plan  -var-file="pro.tfvars"
terraform apply -var-file="pro.tfvars"
```

5) Destroy del entorno (no toca otros entornos):
```powershell
terraform destroy -var-file="pro.tfvars"
```

## Backend
- Bucket S3 de state: 1 por entorno (dev/pre/pro)
- Key: `pro/terraform.tfstate`
- Locks: DynamoDB común
