#!bin/bash

#input Region
#Input AWS account number
#Input AWS User or Role
#Input AWS Username or Role Name
#adjust the above in the ZS-Test-Role-Policy.json
#Input AWS VPC ID to deploy CC creation
#Input AWS Subnet ID to deploy CC creation
#Input AMI for cloud connector (set to east now)
#Input key pair name
#Need output of ELB ARN to use for GWLB 
#Need output of Target Group ARN to delete it

## Cloud Connector Prerequisites Macro Tests

# Check Ability to Create IAM Role and Policies

aws iam create-policy --policy-name ZS-CloudConnector-Test-Role-Policy --policy-document file://ZS-CloudConnector-Test-IAM-Policy.json

aws iam create-role --role-name ZS-CloudConnector-Role-Test --assume-role-policy-document file://ZS-CloudConnector-Test-Role-Policy.json

aws iam put-role-policy --role-name ZS-CloudConnector-Role-Test --policy-name ZS-CloudConnector-Test-Role-Policy --policy-document file://ZS-CloudConnector-Test-IAM-Policy.json

 # Check Ability to Create Lambda Function
aws lambda create-function \
    --function-name ZS-CloudConnector-Test-Function \
    --runtime python3.7 \
    --zip-file fileb://ZS-CloudConnector-Macro.zip \
    --handler index.lambda_handler \
    --role arn:aws:iam::494789115339:role/ZS-CloudConnector-Role-Test

# Check Lambda Function Permission Creation
aws lambda add-permission \
    --function-name ZS-CloudConnector-Test-Function \
    --action lambda:InvokeFunction \
    --statement-id ZS-CloudConnector-Test-Lambda-Permission \
    --principal cloudformation.amazonaws.com

## Cloud Connector EC2 Instance Tests

# Security Groups (Dry Run)
aws ec2 create-security-group \
    --group-name ZS-CloudConnector-Test-SecurityGroup \
    --description "Zscaler Cloud Connector EC2 Security Group Test" \
    --vpc-id vpc-040f72846563f83f3 \
    --dry-run

# Network Interfaces (Dry Run)
aws ec2 create-network-interface \
    --subnet-id subnet-02187be7064951f93 \
    --description "Zscaler Cloud Connector Network Interface Test" \
    --dry-run

# EC2 Instance Profile
aws iam create-instance-profile \
    --instance-profile-name "ZscalerCloudConnectorInstanceProfileTest" 

# EC2 Instance (Dry Run)
aws ec2 run-instances \
    --image-id ami-0b1fa817fac443b7a \
    --count 1 \
    --instance-type t2.medium \
    --key-name zoltan-zscaler-aws \
    --subnet-id subnet-02187be7064951f93 \
    --dry-run

## AWS GWLB for Cloud Connector Tests

# GWLB ELB
aws elbv2 create-load-balancer \
    --name ZS-CloudConnector-Test-GWLB \
    --type gateway \
    --subnets subnet-02187be7064951f93

# Target Group
aws elbv2 create-target-group \
    --name ZS-CloudConnector-Test-TG \
    --protocol GENEVE \
    --port 6081 \
    --target-type ip \
    --vpc-id vpc-040f72846563f83f3

# GWLB (Dry Run)
aws ec2 create-vpc-endpoint-service-configuration \
    --gateway-load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:494789115339:loadbalancer/gwy/ZS-CloudConnector-Test-GWLB/bd261f6182cb7bb9 \
    --acceptance-required \
    --dry-run

# Delete the Test Resources

aws elbv2 delete-target-group \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:494789115339:targetgroup/ZS-CloudConnector-Test-TG/00044d06ff560887e6

aws elbv2 delete-load-balancer \
    --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:494789115339:loadbalancer/gwy/ZS-CloudConnector-Test-GWLB/bd261f6182cb7bb9

aws iam delete-instance-profile \
    --instance-profile-name "ZscalerCloudConnectorInstanceProfileTest" 

aws lambda remove-permission \
    --function-name ZS-CloudConnector-Test-Function \
    --statement-id ZS-CloudConnector-Test-Lambda-Permission

aws lambda delete-function \
    --function-name ZS-CloudConnector-Test-Function 

aws iam delete-policy \
    --policy-arn arn:aws:iam::494789115339:policy/ZS-CloudConnector-Test-Role-Policy

aws iam delete-role-policy \
    --role-name ZS-CloudConnector-Role-Test \
    --policy-name ZS-CloudConnector-Test-Role-Policy

 aws iam delete-role --role-name ZS-CloudConnector-Role-Test 
 