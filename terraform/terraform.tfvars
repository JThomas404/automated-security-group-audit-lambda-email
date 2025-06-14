aws_region = "us-east-1"

tags = {
  Project     = "boto3-sg-audit-script"
  Environment = "Dev"
}

lambda_function_name = "security_group_audit"

ses_verified_sender = "jarredthomas101@gmail.com"
