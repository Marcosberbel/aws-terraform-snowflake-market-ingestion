# module/lambda-api

## Qué crea
- Lambda empaquetada automáticamente desde `source_dir` usando `archive_file`.

## Importante sobre VPC (coste)
- Meter Lambda en VPC suele requerir NAT para salir a internet (coste).
- Para un proyecto “coste 0”, por defecto `in_vpc = false`.
- Aun así, ya tienes módulo VPC listo para cuando pases a ECS/ALB.

## Seguridad
- La Lambda asume un role IAM mínimo (lo crea el módulo `iam`).
- Variables sensibles: usa **GitHub Secrets** (CI) o `*.auto.tfvars` (ignorado por git).
