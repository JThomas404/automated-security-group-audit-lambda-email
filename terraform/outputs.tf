output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.SecurityGroupAudit.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.SecurityGroupAudit.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the IAM role used by the Lambda function."
  value       = aws_iam_role.sg_audit_lambda_role.arn
}

output "ses_verified_sender_arn" {
  value = aws_ses_email_identity.verified_sender.arn
}
