variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "bucket_name" {
  type        = string
  description = "Nombre del bucket (debe ser globalmente único)."
}

variable "versioning" {
  type        = bool
  description = "Habilitar versioning."
  default     = false
}
