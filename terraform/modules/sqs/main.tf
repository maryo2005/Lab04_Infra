variable "environment" {
  type = string
}

resource "aws_sqs_queue" "dlq" {
  name                      = "image-processor-${var.environment}-image-dlq"
  message_retention_seconds = 1209600 # 14 días
}

resource "aws_sqs_queue" "main_queue" {
  name                       = "image-processor-${var.environment}-image-queue"
  visibility_timeout_seconds = 360 
  message_retention_seconds  = 86400 

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

output "main_queue_arn" {
  value = aws_sqs_queue.main_queue.arn
}

output "main_queue_url" {
  value = aws_sqs_queue.main_queue.id
}