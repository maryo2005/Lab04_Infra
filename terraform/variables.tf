variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod)"
  type        = string
  default     = "dev"
}