module "s3" {
  source        = "./modules/s3"
  environment   = var.environment
  sqs_queue_arn = module.sqs.main_queue_arn
}

module "sqs" {
  source      = "./modules/sqs"
  environment = var.environment
  # Construimos el ARN del bucket directo para evitar dependencia circular
  bucket_arn  = "arn:aws:s3:::image-processor-${var.environment}-images-suffix"
}

module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  region      = var.aws_region

  bucket_arn  = "arn:aws:s3:::image-processor-${var.environment}-images-suffix"
}

module "iam" {
  source      = "./modules/iam"
  environment = var.environment
  bucket_arn  = module.s3.bucket_arn
  sqs_arn     = module.sqs.main_queue_arn
}

module "lambda" {
  source             = "./modules/lambda"
  environment        = var.environment
  subnet_ids         = module.vpc.private_subnet_ids
  upload_sg_id       = module.vpc.sg_upload_lambda_id
  crop_sg_id         = module.vpc.sg_crop_lambda_id
  bucket_id          = module.s3.bucket_id
  sqs_main_queue_arn = module.sqs.main_queue_arn
  upload_role_arn    = module.iam.upload_role_arn
  crop_role_arn      = module.iam.crop_role_arn
}