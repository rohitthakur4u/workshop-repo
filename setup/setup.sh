#!/bin/bash

echo "(STEP 1) Installing prerequisites..."
sudo apt update
sudo apt upgrade -y
sudo apt install -y jq

pip install --user --upgrade awscli

echo "(STEP 2) Setting Environment Variables..."

test -n "${AWS_DEFAULT_REGION}" && echo AWS_DEFAULT_REGION is "${AWS_DEFAULT_REGION}" || echo AWS_DEFAULT_REGION is not set

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $AWS_DEFAULT_REGION)
echo "export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}" >> ~/.bashrc
echo "export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}" >> ~/.bash_profile

export AWS_REGION=$AWS_DEFAULT_REGION >> ~/.bashrc
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bashrc
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bash_profile

source ~/.bashrc

aws configure set default.region ${AWS_REGION}
aws configure get default.region

echo "(STEP 3) Creating initial set of IAM Roles for ECS and Load Balancer..."
aws iam get-role --role-name "AWSServiceRoleForElasticLoadBalancing" || aws iam create-service-linked-role --aws-service-name "elasticloadbalancing.amazonaws.com" && echo "Created role: 'AWSServiceRoleForElasticLoadBalancing'" >> /tmp/roles_created.txt

aws iam get-role --role-name "AWSServiceRoleForECS" || aws iam create-service-linked-role --aws-service-name "ecs.amazonaws.com" && echo "Created role: 'AWSServiceRoleForECS'" >> /tmp/roles_created.txt

echo "(STEP 4) Unzipping Sample App..."
unzip SampleApp.zip
cd SampleApp/
ls

echo "(STEP 5) Creating ECR repository..."
aws ecr create-repository \
    --repository-name devops-workshop-app \
    --image-scanning-configuration scanOnPush=false \
    --region ${AWS_REGION}
    
export ECR_REPOSITORY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-workshop-app

echo "(STEP 6) Building Docker image..."

docker build --platform=linux/amd64 -t web-app .

echo "(STEP 7) Pushing image to the repository..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

docker tag web-app:latest ${ECR_REPOSITORY}:latest

docker push ${ECR_REPOSITORY}:latest

echo "(STEP 8) Create required infrastructure..."

aws cloudformation deploy \
  --stack-name devops-cluster \
  --template-file /Workshop/setup/required-infrastructure.yml \
  --parameter-overrides "ContainerImage=${ECR_REPOSITORY}:latest" \
  --capabilities CAPABILITY_NAMED_IAM

echo "(STEP 9) Finalizing Setup..."
#Get Target Group ARNs
export TARGET_GROUP1=$(aws elbv2 describe-target-groups --names ecs-devops-webapp-TG | jq -r '.TargetGroups[0].TargetGroupArn')
export TARGET_GROUP2=$(aws elbv2 describe-target-groups --names ecs-devops-webapp-TG-tmp | jq -r '.TargetGroups[0].TargetGroupArn')
export APP_URL=$(aws cloudformation describe-stacks --stack-name devops-cluster | jq -r '.Stacks[0].Outputs[]|select(.OutputKey=="ExternalUrl")|.OutputValue') 
echo "Well done! Now you can check the web application at: ${APP_URL}"
