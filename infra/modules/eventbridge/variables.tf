variable "project" { type = string }
variable "environment" { type = string }

variable "rule_name" { type = string }
variable "schedule_expression" { type = string } # rate(...) o cron(...)
variable "target_lambda_arn" { type = string }
