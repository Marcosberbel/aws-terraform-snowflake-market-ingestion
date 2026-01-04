variable "project" { type = string }
variable "environment" { type = string }

variable "function_name" { type = string }
variable "role_arn" { type = string }

variable "source_dir" {
  type        = string
  description = "Ruta al código fuente para empaquetar (ej: services/lambda-api)."
}

variable "handler" { type = string }
variable "runtime" { type = string }

variable "in_vpc" {
  type        = bool
  description = "Si true, adjunta Lambda a VPC (ojo: para internet necesitarías NAT)."
  default     = false
}

variable "vpc_subnet_ids" {
  type    = list(string)
  default = []
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = []
}

variable "log_group_name" {
  type        = string
  description = "Nombre del log group (para organización)."
}

variable "environment_variables" {
  type        = map(string)
  description = "Variables de entorno para la Lambda."
  default     = {}
}
