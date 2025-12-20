variable "aws_region" {
  type    = string
  default = "eu-south-2"
}

variable "aws_profile" {
  type    = string
  default = "terraform-dev"
}

variable "fmp_api_key" {
  type      = string
  sensitive = true
}
