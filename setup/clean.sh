#!/bin/sh

echo "(STEP 1) Installing prerequisites..."
sudo apt install -y jq

pip install --user --upgrade awscli

echo "(STEP 2) Setting Environment Variables..."

echo "export AWS_DEFAULT_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)" >> ~/.bashrc
echo "export AWS_REGION=\$AWS_DEFAULT_REGION" >> ~/.bashrc
echo "export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $AWS_DEFAULT_REGION)" >> ~/.bashrc
source ~/.bashrc

test -n "${AWS_REGION}" && echo AWS_REGION is "${AWS_REGION}" || echo AWS_REGION is not set

echo "export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region

echo "(STEP 3) Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name devops-cluster

echo "(STEP 4) Deleting ECR repository..."
aws ecr delete-repository --repository-name devops-workshop-app --region ${AWS_REGION} --force

echo "(STEP 5) Cleanup..."
rm -rf /tmp/roles_created.txt

echo "Done!"
echo

