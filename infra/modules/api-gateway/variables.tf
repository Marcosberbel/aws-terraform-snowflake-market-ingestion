variable "project" { type = string }
variable "environment" { type = string }

variable "api_name" { type = string }

variable "lambda_invoke_arn" {
  type        = string
  description = "Invoke ARN de la Lambda."
}

variable "lambda_function_name" {
  type        = string
  description = "Nombre de la Lambda (para aws_lambda_permission)."
}
