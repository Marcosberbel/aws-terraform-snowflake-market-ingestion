terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Diseño simple: PK = ticker (String)
resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = "ticker"

  attribute {
    name = "ticker"
    type = "S"
  }

  # Cifrado: DynamoDB cifra por defecto. (SSE habilitado por defecto en AWS)
  # PITR (Point-in-time) cuesta dinero, lo dejamos fuera por defecto.

  tags = {
    Name        = var.table_name
    Project     = var.project
    Environment = var.environment
    Purpose     = "market-data"
  }
}
