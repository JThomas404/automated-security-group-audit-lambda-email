data "archive_file" "package_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/security_group_audit.py"
  output_path = "${path.module}/../lambda/security_group_audit.zip"
}

resource "aws_lambda_function" "SecurityGroupAudit" {
  function_name    = var.lambda_function_name
  handler          = "security_group_audit.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.sg_audit_lambda_role.arn
  filename         = data.archive_file.package_lambda.output_path
  source_code_hash = data.archive_file.package_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      SES_SENDER    = var.ses_verified_sender
      SES_RECIPIENT = var.ses_verified_sender
    }
  }


  tags = var.tags
}
