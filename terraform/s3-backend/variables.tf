variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "access_key" {
  description = "AWS access key"
  type = string
  sensitive = true
}

variable "secret_key" {
  description = "AWS secret key"
  type = string
  sensitive = true
}