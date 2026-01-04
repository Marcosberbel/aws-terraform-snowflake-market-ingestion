variable "aws_region" {
  description = "Región AWS"
  type        = string
  default     = "eu-south-2"
}

variable "project" {
  description = "Prefijo del proyecto (para tags/nombres)"
  type        = string
  default     = "market-ingestion"
}

variable "base_principal_arn" {
  description = "ARN del principal que podrá asumir los roles (tu user IAM o tu rol SSO). Ej: arn:aws:iam::123:role/AWSReservedSSO_..."
  type        = string
}

variable "role_name_prefix" {
  description = "Prefijo del nombre del rol (por defecto TerraformRole)"
  type        = string
  default     = "TerraformRole"
}

variable "environments" {
  description = "Lista de entornos"
  type        = list(string)
  default     = ["dev", "pre", "pro"]
}

variable "require_mfa" {
  description = "Si true, exige MFA al asumir rol (ojo: con SSO a veces no aplica bien)."
  type        = bool
  default     = false
}

variable "external_id" {
  description = "ExternalId opcional para sts:AssumeRole (útil en cross-org)."
  type        = string
  default     = null
}

variable "permissions_policy_arns" {
  description = "Policies a adjuntar a cada rol. Para demo/entrevista puedes usar AdministratorAccess."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

variable "tags" {
  description = "Tags extra"
  type        = map(string)
  default     = {}
}
