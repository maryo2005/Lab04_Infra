# 1. Bucket S3
resource "aws_s3_bucket" "images_bucket" {
  bucket = "image-processor-${var.environment}-images-suffix"
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.images_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.images_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. Cola SQS Principal y Dead-Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "image-processor-${var.environment}-image-dlq"
  message_retention_seconds = 1209600 # 14 días
}

resource "aws_sqs_queue" "main_queue" {
  name                       = "image-processor-${var.environment}-image-queue"
  visibility_timeout_seconds = 360 # 6x el timeout del lambda
  message_retention_seconds  = 86400 # 1 día

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# 3. IAM Roles
# Rol para upload-lambda
resource "aws_iam_role" "upload_role" {
  name = "upload-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "upload_basic" {
  role       = aws_iam_role.upload_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Rol para crop-lambda
resource "aws_iam_role" "crop_role" {
  name = "crop-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "crop_basic" {
  role       = aws_iam_role.crop_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}