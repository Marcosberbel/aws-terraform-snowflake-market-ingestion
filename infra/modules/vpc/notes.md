# module/vpc

## Objetivo
Crear una VPC “mínimo coste” y segura:
- VPC + IGW
- 2 subnets públicas (2 AZ)
- Ruta a Internet
- **Gateway endpoints** (gratis) para S3 y DynamoDB

## Por qué así (coste 0)
- NO creamos NAT Gateway (es lo que más te cobra en redes).
- Con esto ya tienes una base para ECS/ALB más adelante.
- Si en el futuro metes subnets privadas, ahí sí valorar NAT o alternativas.

## Inputs
- `vpc_cidr` (ej: 10.10.0.0/16)
- `az_count` (2 recomendado)
