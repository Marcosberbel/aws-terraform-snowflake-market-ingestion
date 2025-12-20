output "api_base_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "quotes_table_name" {
  value = aws_dynamodb_table.quotes.name
}

output "region" {
  value = var.aws_region
}
