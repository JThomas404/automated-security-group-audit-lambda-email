variable "aws_region" {
  description = "Default AWS region for the project resources."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Default tags for the project resources."
  type        = map(string)
  default = {
    Project     = "boto3-sg-audit-script"
    Environment = "Dev"
  }
}

variable "lambda_function_name" {
  description = "Name of the Lambda Function."
  type        = string
  default     = "security_group_audit"
}

variable "ses_verified_sender" {
  description = "Verified SES sender email address"
  type        = string
}

