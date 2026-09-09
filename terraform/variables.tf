variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name used to prefix and tag all resources in this project"
  type        = string
  default     = "step-functions-orders"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_eventbridge_trigger" {
  description = "Whether to create an EventBridge rule that can start the workflow automatically. Disabled by default."
  type        = bool
  default     = false
}