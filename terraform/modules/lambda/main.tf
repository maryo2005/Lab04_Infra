variable "environment" { type = string }
variable "subnet_ids" { type = list(string) }
variable "upload_sg_id" { type = string }
variable "crop_sg_id" { type = string }
variable "bucket_id" { type = string }
variable "sqs_main_queue_arn" { type = string }
variable "upload_role_arn" { type = string }
variable "crop_role_arn" { type = string }

data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../src/upload-lambda"
  output_path = "${path.root}/../src/upload-lambda.zip"
}

data "archive_file" "crop_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../src/crop-lambda"
  output_path = "${path.root}/../src/crop-lambda.zip"
}

# 2. Upload Lambda
resource "aws_lambda_function" "upload_lambda" {
  function_name    = "image-processor-${var.environment}-upload"
  runtime          = "nodejs20.x"
  role             = var.upload_role_arn
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 30
  filename         = data.archive_file.upload_zip.output_path
  source_code_hash = data.archive_file.upload_zip.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.upload_sg_id]
  }

  environment {
    variables = {
      S3_BUCKET     = var.bucket_id
      UPLOAD_PREFIX = "uploads/"
    }
  }
}

# 3. Crop Lambda
resource "aws_lambda_function" "crop_lambda" {
  function_name    = "image-processor-${var.environment}-crop"
  runtime          = "nodejs20.x"
  role             = var.crop_role_arn
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.crop_zip.output_path
  source_code_hash = data.archive_file.crop_zip.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.crop_sg_id]
  }

  environment {
    variables = {
      S3_BUCKET        = var.bucket_id
      PROCESSED_PREFIX = "processed/"
    }
  }
}

# 4. Trigger SQS para Crop Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_main_queue_arn
  function_name    = aws_lambda_function.crop_lambda.arn
  batch_size       = 5
}

# 5. API Gateway
resource "aws_apigatewayv2_api" "upload_api" {
  name          = "image-processor-api-${var.environment}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_methods = ["POST"]
    allow_origins = ["*"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.upload_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.upload_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload_lambda.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.upload_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.upload_api.execution_arn}/*/*"
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}