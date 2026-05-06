output "s3_bucket_name" {
  description = "Nombre del bucket S3 de imágenes"
  value       = aws_s3_bucket.images_bucket.id
}

output "sqs_main_queue_arn" {
  description = "ARN de la cola SQS principal"
  value       = aws_sqs_queue.main_queue.arn
}

output "sqs_dlq_arn" {
  description = "ARN de la cola SQS de mensajes fallidos (DLQ)"
  value       = aws_sqs_queue.dlq.arn
}