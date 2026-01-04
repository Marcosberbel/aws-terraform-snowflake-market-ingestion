variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "vpc_cidr" {
  type        = string
  description = "CIDR de la VPC."
}

variable "az_count" {
  type        = number
  description = "Número de AZs (2 recomendado)."
  default     = 2
}
