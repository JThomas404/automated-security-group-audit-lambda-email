#!/bin/bash
set -e

# Clean previous builds
rm -rf lambda/package
rm -f lambda/security_group_audit.zip

# Create package directory
mkdir -p lambda/package

# Activate virtual environment
source venv/bin/activate

# Install dependencies into package
pip install -r requirements.txt -t lambda/package

# Copy the lambda function into the package
cp lambda/security_group_audit.py lambda/package/

# Zip everything inside the package folder
cd lambda/package
zip -r ../security_group_audit.zip . > /dev/null
