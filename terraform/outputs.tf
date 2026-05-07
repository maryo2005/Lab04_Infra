output "s3_bucket_name" {
  description = "Nombre del bucket S3 de imágenes"
  value       = module.s3.bucket_id
}

output "sqs_main_queue_arn" {
  description = "ARN de la cola SQS principal"
  value       = module.sqs.main_queue_arn
}

output "sqs_dlq_arn" {
  description = "ARN de la cola SQS de mensajes fallidos (DLQ)"
  value       = module.sqs.dlq_arn
}

output "api_gateway_url" {
  description = "URL base del API Gateway para subir imágenes"
  value       = module.lambda.api_gateway_url
}