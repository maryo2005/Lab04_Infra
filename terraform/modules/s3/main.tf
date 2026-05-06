variable "environment" {
  type = string
}

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

output "bucket_id" {
  value = aws_s3_bucket.images_bucket.id
}

output "bucket_arn" {
  value = aws_s3_bucket.images_bucket.arn
}