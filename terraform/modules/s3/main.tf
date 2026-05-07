variable "environment" { type = string }
variable "sqs_queue_arn" { type = string } # NUEVA VARIABLE

# 1. El Bucket Privado
resource "aws_s3_bucket" "images" {
  bucket        = "image-processor-${var.environment}-images-suffix"
  force_destroy = true # Útil para poder borrar el entorno de pruebas rápido
}

# 2. Versionado (Versioning: enabled)
resource "aws_s3_bucket_versioning" "images_versioning" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Cifrado (SSE: AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "images_sse" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Reglas de Ciclo de Vida
resource "aws_s3_bucket_lifecycle_configuration" "images_lifecycle" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "expire-uploads-30-days"
    status = "Enabled"
    filter {
      prefix = "uploads/"
    }
    expiration {
      days = 30
    }
  }

  rule {
    id     = "expire-processed-90-days"
    status = "Enabled"
    filter {
      prefix = "processed/"
    }
    expiration {
      days = 90
    }
  }
}

# 5. Notificación de Eventos
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = var.sqs_queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }
}

output "bucket_id" { value = aws_s3_bucket.images.id }
output "bucket_arn" { value = aws_s3_bucket.images.arn }