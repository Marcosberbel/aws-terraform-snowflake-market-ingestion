terraform {
  backend "s3" {
    bucket         = "tf-atsmi-dev-eu-south-2"
    key            = "dev/terraform.tfstate"
    region         = "eu-south-2"
    dynamodb_table = "tf-locks-atsmi-eu-south-2"
    encrypt        = true
  }
}
