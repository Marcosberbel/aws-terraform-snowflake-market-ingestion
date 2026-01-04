output "state_buckets" {
  description = "Mapa de entorno -> bucket de state."
  value       = { for k, v in aws_s3_bucket.tfstate : k => v.bucket }
}

output "lock_table_name" {
  description = "Nombre de la tabla DynamoDB de locking."
  value       = aws_dynamodb_table.locks.name
}
