import boto3
import os

def lambda_handler(event, context):
    # Initialize EC2 and SES clients
    ec2 = boto3.client('ec2')
    ses = boto3.client('ses')

    # Load sender and recipient email addresses from environment variables
    sender = os.environ['SES_SENDER']
    recipient = os.environ['SES_RECIPIENT']

    # Describe all security groups in the account/region
    response = ec2.describe_security_groups()
    insecure_rules = []

    # Iterate over each security group and check inbound rules
    for sg in response['SecurityGroups']:
        group_id = sg['GroupId']
        group_name = sg.get('GroupName', 'Unnamed')

        for permission in sg.get('IpPermissions', []):
            for ip_range in permission.get('IpRanges', []):
                if ip_range.get('CidrIp') == '0.0.0.0/0':
                    # Log the insecure rule
                    rule_info = (
                        f"Security Group '{group_name}' ({group_id}) allows inbound access "
                        f"from 0.0.0.0/0.\nRule: {permission}\n"
                    )
                    insecure_rules.append(rule_info)

    # If any insecure rules were found, send an alert via SES
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

    # Return basic Lambda response
    return {
        'statusCode': 200,
        'body': f'Audit complete. {len(insecure_rules)} insecure rules found.'
    }
