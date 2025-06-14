resource "aws_ses_email_identity" "verified_sender" {
  email = var.ses_verified_sender
}
