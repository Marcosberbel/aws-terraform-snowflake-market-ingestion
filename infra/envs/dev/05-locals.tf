locals {
  project = "market-ingestion"
  env     = "dev"

  tags = {
    Project     = local.project
    Environment = local.env
    ManagedBy   = "terraform"
  }
}
