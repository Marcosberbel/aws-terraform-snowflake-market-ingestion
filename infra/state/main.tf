terraform {
  # Importante: backend local a propósito.
  # Este root crea el backend remoto (S3 + DynamoDB).
  backend "local" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ProjectId = var.project_short
      ManagedBy = "terraform"
      Purpose   = "terraform-backend"
    }
  }
}

locals {
  # sufijo opcional "-algo"
  suffix = var.bucket_suffix != "" ? "-${var.bucket_suffix}" : ""

  # Buckets de state por entorno (SIN account_id)
  # Ej: tf-atsmi-dev-eu-south-2
  state_bucket_names = {
    for env in var.environments :
    env => "tf-${var.project_short}-${env}-${var.region}${local.suffix}"
  }

  # DynamoDB locks (SIN account_id)
  # 1 tabla común para todos los entornos (pro)
  lock_table_name = "tf-locks-${var.project_short}-${var.region}"

  common_tags = {
    Project   = var.project
    ProjectId = var.project_short
    ManagedBy = "terraform"
    Purpose   = "terraform-backend"
  }
}

#############################
# S3 buckets (state)
#############################
resource "aws_s3_bucket" "tfstate" {
  for_each = local.state_bucket_names
  bucket   = each.value

  force_destroy = false

  lifecycle {
    precondition {
      condition     = length(each.value) <= 63
      error_message = "Bucket name demasiado largo: ${each.value}"
    }
  }

  tags = merge(local.common_tags, { Environment = each.key, Name = each.value })
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  for_each = aws_s3_bucket.tfstate
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  for_each = aws_s3_bucket.tfstate
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  for_each = aws_s3_bucket.tfstate
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#############################
# DynamoDB locks (1 tabla común)
#############################
resource "aws_dynamodb_table" "locks" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, { Name = local.lock_table_name })
}
