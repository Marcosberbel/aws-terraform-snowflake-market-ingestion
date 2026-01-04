#############################################
# Root del entorno (solo orquesta módulos)
#############################################

module "vpc" {
  source      = "../../modules/vpc"
  project     = var.project
  environment = var.environment
  region      = var.region

  vpc_cidr = "10.10.0.0/16"
  az_count = 2
}

module "cloudwatch" {
  source      = "../../modules/cloudwatch"
  project     = var.project
  environment = var.environment

  log_group_name    = "/${var.project}/${var.environment}/lambda"
  retention_in_days = var.log_retention_days
}

module "s3_storage" {
  source      = "../../modules/s3-storage"
  project     = var.project
  environment = var.environment
  region      = var.region

  bucket_name = "${var.project}-${var.environment}-storage-${var.region}"
  versioning  = var.enable_storage_versioning
}

module "dynamodb" {
  source      = "../../modules/dynamodb"
  project     = var.project
  environment = var.environment

  table_name   = "${var.project}-${var.environment}-market"
  billing_mode = "PAY_PER_REQUEST"
}

module "iam" {
  source      = "../../modules/iam"
  project     = var.project
  environment = var.environment

  dynamodb_table_arn = module.dynamodb.table_arn
  log_group_arn      = module.cloudwatch.log_group_arn
}

module "lambda_api" {
  source      = "../../modules/lambda-api"
  project     = var.project
  environment = var.environment

  function_name  = "${var.project}-${var.environment}-api"
  role_arn       = module.iam.lambda_role_arn
  log_group_name = module.cloudwatch.log_group_name

  # Código ejemplo (zip se genera con archive_file desde esta carpeta)
  source_dir = "../../../services/lambda-api"
  handler    = "handler.lambda_handler"
  runtime    = "python3.11"

  # Permisos de red: NO metemos Lambda dentro de VPC para evitar NAT (coste).
  # Aun así creamos la VPC como base del proyecto.
  in_vpc = false
}

module "api_gateway" {
  source      = "../../modules/api-gateway"
  project     = var.project
  environment = var.environment

  api_name             = "${var.project}-${var.environment}-http-api"
  lambda_invoke_arn    = module.lambda_api.invoke_arn
  lambda_function_name = module.lambda_api.function_name
}

module "eventbridge" {
  source      = "../../modules/eventbridge"
  project     = var.project
  environment = var.environment

  rule_name           = "${var.project}-${var.environment}-hourly"
  schedule_expression = "rate(1 hour)"
  target_lambda_arn   = module.lambda_api.arn
}
