variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "app_image_tag" {
  description = "Container image tag for the API service"
  type        = string
  default     = "latest"
}
