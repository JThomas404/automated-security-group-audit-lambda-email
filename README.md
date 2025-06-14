# Security Group Audit via Lambda

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [How the Lambda Function Works](#how-the-lambda-function-works)
- [Lambda Function Script Breakdown](#lambda-function-script-breakdown)
- [Terraform Infrastructure Breakdown](#terraform-infrastructure-breakdown)
- [Bash Script Explanation](#bash-script-explanation)
- [Tasks and IaC Implementation Steps](#tasks-and-iac-implementation-steps)
- [Local Testing](#local-testing)
- [Lambda Deployment with Environment Variables](#lambda-deployment-with-environment-variables)
- [IAM Role and Permissions](#iam-role-and-permissions)
- [Design Decisions and Highlights](#design-decisions-and-highlights)
- [Errors Encountered](#errors-encountered)
- [Skills Demonstrated](#skills-demonstrated)
- [Conclusion](#conclusion)

---

## Overview

This project implements a serverless security auditing solution for Amazon EC2 Security Groups. A scheduled AWS Lambda function iterates through all security groups and checks for overly permissive rules (e.g., `0.0.0.0/0`). When violations are found, alerts are sent via Amazon SES email notifications.

---

## Real-World Business Value

Security groups with unrestricted access can pose significant threats, especially in production environments. This automation provides real-time awareness of misconfigurations, reduces manual auditing overhead, and enhances proactive security posture for cloud infrastructure teams.

---

## Prerequisites

- Verified Amazon SES sender email address in the same AWS Region
- IAM Role with `ec2:DescribeSecurityGroups` and `ses:SendEmail` permissions
- Terraform CLI and AWS CLI configured
- Python 3.11 in a virtual environment

---

## Project Folder Structure

```
automated-security-group-audit-lambda-email/
├── lambda
│   └── security_group_audit.py
├── README.md
├── requirements.txt
├── scripts
│   ├── event.json
│   └── package-lambda.sh
├── terraform
│   ├── iam.tf
│   ├── lambda.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── ses.tf
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   ├── terraform.tfvars
│   └── variables.tf
└── venv/
```

---

## How the Lambda Function Works

1. The function is triggered manually or via CloudWatch Events.
2. It uses the `boto3` EC2 client to describe all security groups.
3. Inbound rules are scanned for any `0.0.0.0/0` entries.
4. If found, an alert is sent to a verified SES recipient email.
5. Logs are pushed to CloudWatch.

---

## Lambda Function Script Breakdown

### Setup and Configuration

```python
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.resource('ec2')
ses = boto3.client('ses')
SES_SENDER = os.environ['SES_SENDER']
SES_RECIPIENT = os.environ['SES_RECIPIENT']
```

### Security Group Scan

```python
def lambda_handler(event, context):
    security_groups = ec2.security_groups.all()
    for sg in security_groups:
        for permission in sg.ip_permissions:
            for ip_range in permission.get('IpRanges', []):
                if ip_range.get('CidrIp') == '0.0.0.0/0':
                    alert = f"Security group {sg.id} ({sg.group_name}) allows inbound from 0.0.0.0/0."
                    logger.warning(alert)
                    send_email(alert)
    return {'statusCode': 200, 'body': 'Audit complete.'}
```

### Email Notification

```python
def send_email(body):
    ses.send_email(
        Source=SES_SENDER,
        Destination={'ToAddresses': [SES_RECIPIENT]},
        Message={
            'Subject': {'Data': 'Security Group Audit Alert'},
            'Body': {'Text': {'Data': body}}
        }
    )
```

---

## Terraform Infrastructure Breakdown

- The Lambda function and all its components are provisioned using Terraform, ensuring a repeatable, version-controlled infrastructure.
- IAM policies follow **principle of least privilege**—only `ec2:DescribeSecurityGroups`, `ses:SendEmail`, and minimal logging permissions are granted.
- Environment variables are injected securely from `terraform.tfvars`.
- The AWS provider version is explicitly updated to the latest to ensure compatibility with `python3.11` Lambda runtime.
- Use of `source_code_hash` in the Lambda resource ensures updates are triggered only when code changes.
- SES identity verification is automated through `ses.tf`.

---

## Bash Script Explanation

The `package-lambda.sh` script automates the packaging of the Lambda function into a ZIP archive:

```bash
#!/bin/bash
zip -j ../lambda/security_group_audit.zip ../lambda/security_group_audit.py
```

### Purpose:

- Automates manual ZIP creation to avoid human error.
- Ensures consistent file structure.
- Used by Terraform's `archive_file` to package the code for deployment.

You simply run the script from the `scripts/` directory before applying Terraform.

---

## Tasks and IaC Implementation Steps

1. Create IAM role and policy
2. Deploy Lambda function with Terraform
3. Set environment variables for SES sender/recipient
4. Package and upload code using `archive_file`
5. Optionally schedule Lambda using CloudWatch

---

## Local Testing

Use `event.json` to test the function locally:

```bash
python3 lambda/security_group_audit.py
```

Or invoke via AWS Console with test event.

---

## Lambda Deployment with Environment Variables

Defined in `lambda.tf`:

```hcl
environment {
  variables = {
    SES_SENDER    = var.ses_verified_sender
    SES_RECIPIENT = var.ses_verified_sender
  }
}
```

---

## IAM Role and Permissions

```hcl
resource "aws_iam_role_policy" "sg_audit_lambda_policy" {
  name = "sg-audit-lambda-policy"
  role = aws_iam_role.sg_audit_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AllowDescribeSecurityGroups",
        Effect: "Allow",
        Action: ["ec2:DescribeSecurityGroups"],
        Resource: "*"
      },
      {
        Sid: "AllowSESSendEmail",
        Effect: "Allow",
        Action: ["ses:SendEmail", "ses:SendRawEmail"],
        Resource: "*"
      },
      {
        Sid: "AllowCloudWatchLogging",
        Effect: "Allow",
        Action: [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource: "*"
      }
    ]
  })
}
```

---

## Design Decisions and Highlights

- **Inline Email Notifications**: Chose SES over SNS to allow custom formatting and direct delivery.
- **Terraform Packaging**: Ensures Lambda updates are tracked via `source_code_hash`.
- **Environment Isolation**: Used virtual environment to manage dependencies.
- **Minimalist Python Design**: Script avoids unnecessary logic and handles all failure cases.
- **Updated Provider Versions**: Terraform AWS provider supports `python3.11` and platform compatibility (e.g., `darwin_arm64`).
- **Secure IAM**: Role-based access limited to exact actions needed, no wildcard administrative access.

---

## Errors Encountered

- `InvalidParameterValueException: Uploaded file must be a non-empty zip`

  - Caused by packaging error; resolved by checking `archive_file` and `output_path`

- IAM role reference error using `.id` instead of `.arn`
- SES verification required in same AWS region as Lambda

---

## Skills Demonstrated

- Secure auditing of EC2 security groups
- SES integration for automated alerts
- Serverless deployment and packaging with Terraform
- IAM policy creation and permission scoping
- Python logging and resource scanning with `boto3`
- Bash scripting to automate Lambda packaging

---

## Conclusion

This project is a practical solution for continuous security auditing in AWS. It demonstrates the value of automation in enforcing infrastructure hygiene and offers a strong baseline for more advanced compliance or intrusion detection pipelines.

---
