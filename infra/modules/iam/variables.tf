variable "project" { type = string }
variable "environment" { type = string }

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN de la tabla DynamoDB para permisos mínimos."
}

variable "log_group_arn" {
  type        = string
  description = "ARN del log group para permisos de logs."
}
