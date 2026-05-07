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

  receive_wait_time_seconds  = 20

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

output "dlq_arn" {
  description = "ARN de la cola de mensajes fallidos"
  value       = aws_sqs_queue.dlq.arn
}


resource "aws_sns_topic" "dlq_alarms" {
  name = "dlq-alarms-topic-${var.environment}"
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages_alarm" {
  alarm_name          = "dlq-messages-alarm-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60 # Period: 60 s
  statistic           = "Sum"
  threshold           = 0  # Threshold: above 0
  alarm_description   = "Alarma que se dispara si hay mensajes estancados en la DLQ"
  
  alarm_actions       = [aws_sns_topic.dlq_alarms.arn]

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}

variable "bucket_arn" { type = string } # Necesitamos saber quién nos habla

# Permiso para que S3 envíe eventos a la cola Principal
resource "aws_sqs_queue_policy" "s3_to_sqs" {
  queue_url = aws_sqs_queue.main_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main_queue.arn
      Condition = {
        ArnLike = { "aws:SourceArn" : var.bucket_arn }
      }
    }]
  })
}