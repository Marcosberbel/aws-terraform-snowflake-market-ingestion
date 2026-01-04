variable "project" { type = string }
variable "environment" { type = string }

variable "table_name" {
  type        = string
  description = "Nombre de la tabla DynamoDB."
}

variable "billing_mode" {
  type        = string
  description = "PAY_PER_REQUEST recomendado para coste variable."
  default     = "PAY_PER_REQUEST"
}
