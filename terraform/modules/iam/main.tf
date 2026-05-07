variable "environment" { type = string }
variable "bucket_arn" { type = string }
variable "sqs_arn" { type = string }

# ROL 1: UPLOAD LAMBDA
resource "aws_iam_role" "upload_role" {
  name = "upload-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

# Políticas base
resource "aws_iam_role_policy_attachment" "upload_basic" {
  role       = aws_iam_role.upload_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "upload_vpc" {
  role       = aws_iam_role.upload_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Política custom: s3:PutObject scoped to uploads/ only
resource "aws_iam_policy" "upload_s3" {
  name = "upload-s3-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = ["${var.bucket_arn}/uploads/*"]
    }]
  })
}
resource "aws_iam_role_policy_attachment" "upload_s3_attach" {
  role       = aws_iam_role.upload_role.name
  policy_arn = aws_iam_policy.upload_s3.arn
}

# ROL 2: CROP LAMBDA
resource "aws_iam_role" "crop_role" {
  name = "crop-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

# Políticas base
resource "aws_iam_role_policy_attachment" "crop_basic" {
  role       = aws_iam_role.crop_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "crop_vpc" {
  role       = aws_iam_role.crop_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Política custom: s3 y sqs
resource "aws_iam_policy" "crop_s3_sqs" {
  name = "crop-s3-sqs-policy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${var.bucket_arn}/uploads/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${var.bucket_arn}/processed/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = [var.sqs_arn]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "crop_custom_attach" {
  role       = aws_iam_role.crop_role.name
  policy_arn = aws_iam_policy.crop_s3_sqs.arn
}

# Outputs para el módulo Lambda
output "upload_role_arn" { value = aws_iam_role.upload_role.arn }
output "crop_role_arn" { value = aws_iam_role.crop_role.arn }