terraform {
  backend "s3" {
    bucket         = "marcos-tfstate-market-ingestion-eu-south-2-001"
    key            = "market-ingestion/dev/terraform.tfstate"
    region         = "eu-south-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
