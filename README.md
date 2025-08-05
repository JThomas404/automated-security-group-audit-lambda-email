# Automated Security Group Audit via Lambda

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [Tasks and Implementation Steps](#tasks-and-implementation-steps)
- [Core Implementation Breakdown](#core-implementation-breakdown)
- [Local Testing and Debugging](#local-testing-and-debugging)
- [IAM Role and Permissions](#iam-role-and-permissions)
- [Design Decisions and Highlights](#design-decisions-and-highlights)
- [Errors Encountered and Resolved](#errors-encountered-and-resolved)
- [Skills Demonstrated](#skills-demonstrated)
- [Conclusion](#conclusion)

---

## Overview

This project implements a serverless security auditing solution that automatically scans Amazon EC2 Security Groups for overly permissive inbound rules. The solution utilises AWS Lambda to perform scheduled audits, identifying security groups with unrestricted access (`0.0.0.0/0`) and delivering immediate email alerts via Amazon SES. The entire infrastructure is provisioned using Terraform with Infrastructure as Code principles, ensuring reproducible deployments and version-controlled security policies.

---

## Real-World Business Value

Security groups with unrestricted inbound access represent critical attack vectors in cloud environments, particularly for production workloads. This automated auditing solution addresses several business-critical requirements:

- **Proactive Security Monitoring**: Continuous detection of misconfigurations before they can be exploited
- **Compliance Automation**: Reduces manual audit overhead whilst maintaining security governance standards
- **Cost-Effective Alerting**: Serverless architecture ensures minimal operational costs with pay-per-execution pricing
- **Scalable Security**: Automatically scales across multiple AWS accounts and regions without infrastructure management

The solution provides immediate visibility into security posture violations, enabling rapid remediation and reducing the window of exposure for potential security incidents.

---

## Prerequisites

- AWS CLI configured with appropriate credentials and region settings
- Terraform CLI (version ≥ 1.3.0) installed and configured
- Verified Amazon SES sender email address in the target AWS region
- Python 3.11 runtime environment with virtual environment support
- IAM permissions for Lambda, EC2, SES, and CloudWatch services

---

## Project Folder Structure

```
automated-security-group-audit-lambda-email/
├── lambda/
│   └── security_group_audit.py
├── scripts/
│   ├── event.json
│   └── package-lambda.sh
├── terraform/
│   ├── iam.tf
│   ├── lambda.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── ses.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── .gitignore
├── README.md
└── requirements.txt
```

---

## Tasks and Implementation Steps

1. **Infrastructure Provisioning**: Deploy IAM roles, Lambda function, and SES configuration using Terraform
2. **Security Policy Configuration**: Implement least-privilege IAM policies for EC2 and SES access
3. **Lambda Deployment**: Package and deploy Python function with automated dependency management
4. **Environment Configuration**: Secure injection of SES sender/recipient email addresses via environment variables
5. **Testing and Validation**: Local testing with mock events and production validation via AWS Console

---

## Core Implementation Breakdown

### Lambda Function Architecture

The core auditing logic is implemented in [`lambda/security_group_audit.py`](lambda/security_group_audit.py):

```python
def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    ses = boto3.client('ses')

    sender = os.environ['SES_SENDER']
    recipient = os.environ['SES_RECIPIENT']

    response = ec2.describe_security_groups()
    insecure_rules = []

    for sg in response['SecurityGroups']:
        for permission in sg.get('IpPermissions', []):
            for ip_range in permission.get('IpRanges', []):
                if ip_range.get('CidrIp') == '0.0.0.0/0':
                    rule_info = (
                        f"Security Group '{sg.get('GroupName', 'Unnamed')}' "
                        f"({sg['GroupId']}) allows inbound access from 0.0.0.0/0"
                    )
                    insecure_rules.append(rule_info)

    # Send email alert if violations found
    if insecure_rules:
        message_body = "Security Group Audit Report:\n\n" + "\n".join(insecure_rules)
        ses.send_email(
            Source=sender,
            Destination={'ToAddresses': [recipient]},
            Message={
                'Subject': {'Data': 'Security Group Audit Alert'},
                'Body': {'Text': {'Data': message_body}}
            }
        )

    return {
        'statusCode': 200,
        'body': f'Audit complete. {len(insecure_rules)} insecure rules found.'
    }
```

### Terraform Infrastructure Configuration

The infrastructure is defined across modular Terraform files:

- **[`terraform/main.tf`](terraform/main.tf)**: Provider configuration with AWS provider version 5.75.0
- **[`terraform/lambda.tf`](terraform/lambda.tf)**: Lambda function resource with Python 3.11 runtime
- **[`terraform/iam.tf`](terraform/iam.tf)**: IAM roles and policies following least-privilege principles
- **[`terraform/ses.tf`](terraform/ses.tf)**: SES email identity verification for automated sender setup
- **[`terraform/variables.tf`](terraform/variables.tf)**: Parameterised configuration for environment flexibility

### Automated Packaging Pipeline

The [`scripts/package-lambda.sh`](scripts/package-lambda.sh) script automates Lambda deployment preparation:

```bash
#!/bin/bash
set -e

rm -rf lambda/package
mkdir -p lambda/package

source venv/bin/activate
pip install -r requirements.txt -t lambda/package
cp lambda/security_group_audit.py lambda/package/

cd lambda/package
zip -r ../security_group_audit.zip . > /dev/null
```

---

## Local Testing and Debugging

### Local Function Testing

The Lambda function can be tested locally using the provided test event:

```bash
# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables for local testing
export SES_SENDER="your-verified-email@domain.com"
export SES_RECIPIENT="recipient@domain.com"

# Execute function locally
python3 lambda/security_group_audit.py
```

### AWS Console Testing

Deploy the function and test using the AWS Lambda Console with the provided [`scripts/event.json`](scripts/event.json) test event. The test event uses an empty JSON object `{}` as Lambda functions can be triggered without specific event data. Monitor execution via CloudWatch Logs for detailed audit results and error diagnostics.

---

## IAM Role and Permissions

The IAM configuration implements strict least-privilege access controls:

```hcl
resource "aws_iam_role_policy" "sg_audit_lambda_policy" {
  name = "sg-audit-lambda-policy"
  role = aws_iam_role.sg_audit_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowDescribeSecurityGroups"
        Effect = "Allow"
        Action = ["ec2:DescribeSecurityGroups"]
        Resource = "*"
      },
      {
        Sid    = "AllowSESSendEmail"
        Effect = "Allow"
        Action = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
```

---

## Design Decisions and Highlights

### Architecture Choices

- **Serverless-First Approach**: Lambda provides cost-effective execution with automatic scaling and zero infrastructure management overhead
- **Direct SES Integration**: Chosen over SNS for enhanced email formatting control and reduced service complexity
- **Terraform State Management**: Infrastructure as Code ensures reproducible deployments and change tracking
- **Environment Variable Security**: Sensitive configuration isolated from code through secure environment variable injection

### Technical Implementation Highlights

- **Latest AWS Provider**: Terraform AWS provider version 5.75.0 ensures compatibility with Python 3.11 Lambda runtime
- **Source Code Hash Tracking**: Terraform `source_code_hash` attribute ensures Lambda updates trigger only on actual code changes
- **Modular Terraform Design**: Separated concerns across multiple `.tf` files for maintainability and reusability
- **Dependency Pinning**: Explicit boto3 version specification in [`requirements.txt`](requirements.txt) ensures consistent behaviour across deployments

### Security Considerations

- **Least Privilege IAM**: Role permissions restricted to exact actions required for functionality
- **Regional SES Verification**: Email sender verification enforced within the same AWS region as Lambda deployment
- **Environment Variable Security**: Sensitive email addresses isolated from code through secure environment variable injection
- **Resource Scoping**: Lambda timeout set to 30 seconds to prevent runaway executions

---

## Errors Encountered and Resolved

### Lambda Packaging Issues

**Error**: `InvalidParameterValueException: Uploaded file must be a non-empty zip`

**Resolution**: Implemented proper `archive_file` data source configuration in Terraform with correct `output_path` specification. Enhanced packaging script to ensure consistent ZIP file structure.

### IAM Role Reference Errors

**Error**: IAM role reference using `.id` instead of `.arn` in Lambda function configuration

**Resolution**: Corrected Terraform resource references to use `aws_iam_role.sg_audit_lambda_role.arn` for proper Lambda execution role assignment.

### SES Regional Verification

**Error**: SES email sending failures due to unverified sender in target region

**Resolution**: Automated SES identity verification through dedicated [`terraform/ses.tf`](terraform/ses.tf) configuration using `aws_ses_email_identity` resource, ensuring sender verification in the same region as Lambda deployment.

---

## Skills Demonstrated

- **Serverless Architecture Design**: Implementation of event-driven security auditing with AWS Lambda
- **Infrastructure as Code**: Terraform configuration with modular design and version control
- **Security-First Development**: IAM least-privilege implementation and secure environment variable management
- **Python Development**: Boto3 SDK utilisation for AWS service integration and error handling
- **DevOps Automation**: Bash scripting for deployment pipeline automation and dependency management
- **Cloud Security Auditing**: Automated detection of security group misconfigurations and compliance violations
- **Email Integration**: Amazon SES configuration for automated alerting and notification systems

---

## Conclusion

This project demonstrates a production-ready approach to automated security auditing in AWS environments. The solution combines serverless architecture principles with Infrastructure as Code practices to deliver a scalable, cost-effective security monitoring capability. The implementation showcases practical application of AWS services integration, security-conscious design patterns, and operational automation—providing a foundation for enterprise-scale security governance and compliance monitoring systems.

The modular Terraform configuration and comprehensive error handling ensure the solution can be adapted and extended for more complex security auditing requirements, including multi-account deployments and integration with existing security information and event management (SIEM) systems.
