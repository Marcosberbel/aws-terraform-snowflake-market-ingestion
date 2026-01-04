variable "project" {
  type        = string
  description = "Nombre del proyecto (tags/nombres)."
}

variable "environment" {
  type        = string
  description = "Entorno: dev/pre/pro."
}

variable "region" {
  type        = string
  description = "Región AWS (por defecto eu-south-2)."
  default     = "eu-south-2"
}

variable "aws_profile" {
  type        = string
  description = "Perfil AWS CLI a usar (opcional). Ej: terraform-dev"
  default     = ""
}

# Ajustes por entorno (ejemplos)
variable "enable_storage_versioning" {
  type        = bool
  description = "Versionado del bucket S3 'storage' (no state)."
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "Retención de logs CloudWatch."
  default     = 14
}
