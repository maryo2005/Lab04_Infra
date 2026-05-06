module "s3" {
  source      = "./modules/s3"
  environment = var.environment
}

module "sqs" {
  source      = "./modules/sqs"
  environment = var.environment
}

module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  region      = var.aws_region
}