variable "project" { type = string }
variable "environment" { type = string }

variable "log_group_name" {
  type        = string
  description = "Nombre del log group."
}

variable "retention_in_days" {
  type        = number
  description = "Retención de logs."
  default     = 14
}
