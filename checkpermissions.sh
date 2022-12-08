#bin/bash

set -e
red=`tput setaf 1`
purple=`tput setaf 5`
blue=`tput setaf 4`
reset=`tput sgr0`

if [[  -e ./.awsinfo ]]; then
    # initialize environment variables
    . ./.awsinfo
else
    echo "Example Account: 012345678901"
    echo "Example Region : us-east-1"
    echo "Example VPC Id: vpc-01234567890123456"
    echo "Example Subnet Id: subnet-01234567890123456"
    echo "Example AWS Key Pair Name: my-kepair-name"
    echo "Example ZS Cloud Connector AMI: ami-01234567890123456"
    echo ""

    echo "${purple}"
    read -p "AWS Account: " account
    echo "export AWS_ACCESS_KEY_ID=${account}" > .awsinfo
    echo ""
    echo "AWS Regions: "af-south-1","ap-east-1","ap-northeast-1","ap-northeast-2","ap-northeast-3","ap-south-1","ap-southeast-1","ap-southeast-2","ca-central-1","cn-north-1","cn-northwest-1","eu-central-1","eu-north-1","eu-south-1","eu-west-1","eu-west-2","eu-west-3","me-south-1","sa-east-1","us-east-1","us-east-2","us-gov-east-1","us-gov-west-1","us-west-1","us-west-2""
    echo ""
    read -p "AWS Region: " region
    read -p "AWS VPC Id: " vpcid
    read -p "AWS Subnet Id: " subnetid
    read -p "AWS SSH Key Pair Name: " keypair
    CC="https://aws.amazon.com/marketplace/pp/prodview-cvzx4oiv7oljm"
    MARKETPLACE_URL_REGEXP="^https://aws.amazon.com/marketplace/pp/prodview-cvzx4oiv7oljm"
    MARKETPLACE_HTML_PRODUCTID_REGEXP="/marketplace/fulfillment\?productId=([a-f0-9-]+)"

    # fetch product ID from marketplace page source
    if [[ ! $(curl --silent "$CC") =~ $MARKETPLACE_HTML_PRODUCTID_REGEXP ]]; then
        exitError "Unable to extract product ID from marketplace page. Please try again..."
    fi

    # list available AMI entities associated with marketplace product ID
    zsccami=$(aws ec2 describe-images \
        --filters "Name=name,Values=*-${BASH_REMATCH[1]}-*" \
        --output text \
        --query "reverse(sort_by(Images,&CreationDate))[].[join(':',[ImageId,CreationDate,Description])]" \
        --region $region | sed 's/:.*//')
    echo "export account=${account}" > .awsinfo
    echo "export region=${region}" >> .awsinfo
    echo "export vpcid=${vpcid}" >> .awsinfo
    echo "export subnetid=${subnetid}" >> .awsinfo
    echo "export keypair=${keypair}" >> .awsinfo
    echo "export zsccami=${zsccami}" >> .awsinfo
    echo "${reset}"
fi

#User confirm to start tests
read -p "${purple}Press enter to start creating test resources...${reset}"
echo ""

#Generate Random Number
random=$(echo $(( $RANDOM % 98 + 1 )))
echo "Random number used for suffix of all test resource for this test run is: $random"
echo ""
## Cloud Connector Prerequisites Macro Tests Section

# Check Ability to Create IAM Role and Policies
echo "Creating IAM Role..."
if ! aws iam create-role --role-name ZS-CC-Role-Test-$random --assume-role-policy-document file://ZS-CloudConnector-Test-Role-Policy.json --region $region 2>&1 | grep -q 'RoleName' 
then
    echo "${red}FAILED. You do not have permissions to create an IAM Role...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create an IAM Role...${reset}"
    echo ""
fi
sleep 5

echo "Attaching Test IAM Policy to Test Role..."
if ! aws iam put-role-policy --role-name ZS-CC-Role-Test-$random --policy-name ZS-CC-Test-Role-Policy-$random --policy-document file://ZS-CloudConnector-Test-IAM-Policy.json --region $region 2>&1
then
    echo "${red}FAILED. You do not have permissions to attach a Policy to an IAM Role...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can attach a Policy to an IAM Role...${reset}"
    echo ""
fi
sleep 5

 # Check Ability to Create Lambda Function
echo "Creating Test Lambda Function..."
if ! aws lambda create-function \
    --region $region \
    --function-name ZS-CC-Test-Function-$random \
    --runtime python3.7 \
    --zip-file fileb://ZS-CloudConnector-Macro.zip \
    --handler index.lambda_handler \
    --role arn:aws:iam::$account:role/ZS-CC-Role-Test-$random 2>&1 | grep -q 'FunctionName' 
then
    echo "${red}FAILED. You do not have permissions to create a Lambda Function...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create a Lambda Function...${reset}"
    echo ""
fi

# Check Lambda Function Permission Creation
echo "Creating Test Lambda Permissions..."
if ! aws lambda add-permission \
    --region $region \
    --function-name ZS-CC-Test-Function-$random \
    --action lambda:InvokeFunction \
    --statement-id ZS-CC-Test-Lambda-Permission-$random \
    --principal cloudformation.amazonaws.com 2>&1 | grep -q 'arn' 
then
    echo "${red}FAILED. You do not have permissions to create Lambda Permissions...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create Lambda Permissions...${reset}"
    echo ""
fi

## Cloud Connector EC2 Instance Tests Section

# Security Groups (Dry Run)
echo "Creating Test Security Group (Dry Run)..."
if ! aws ec2 create-security-group \
    --region $region \
    --group-name ZS-CC-Test-SecurityGroup-$random \
    --description "Zscaler Cloud Connector EC2 Security Group Test" \
    --vpc-id $vpcid \
    --dry-run 2>&1 | grep -q 'Request would have succeeded' 
then
    echo "${red}FAILED. You do not have permissions to create Security Groups...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create Security Groups...${reset}"
    echo ""
fi

# Network Interfaces (Dry Run)
echo "Creating Test Network Interface (Dry Run)..."
if ! aws ec2 create-network-interface \
    --region $region \
    --subnet-id $subnetid \
    --description "Zscaler Cloud Connector Network Interface Test" \
    --dry-run 2>&1 | grep -q 'Request would have succeeded' 
then
    echo "${red}FAILED. You do not have permissions to create Network Interfaces...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create Network Interfaces...${reset}"
    echo ""
fi

# EC2 Instance Profile
echo "Creating Test Instance Profile..."
if ! aws iam create-instance-profile \
    --region $region \
    --instance-profile-name "ZscalerCCInstanceProfileTest-$random"  2>&1 | grep -q 'Arn' 
then
    echo "${red}FAILED. You do not have permissions to create an EC2 Instance Profile...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create an EC2 Instance Profile...${reset}"
    echo ""
fi

# EC2 Instance (Dry Run)
echo "Creating Test EC2 Cloud Connector Instance (Dry Run)..."
if ! aws ec2 run-instances \
    --region $region \
    --image-id $zsccami \
    --count 1 \
    --instance-type t2.medium \
    --key-name $keypair \
    --subnet-id $subnetid \
    --dry-run 2>&1 | grep -q 'Request would have succeeded' 
then
    echo "${red}FAILED. You do not have permissions to create EC2 Instances...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create EC2 Instances...${reset}"
    echo ""
fi

## AWS GWLB for Cloud Connector Tests Section

# GWLB ELB
echo "Creating Test Load Balancer..."
if ! aws elbv2 create-load-balancer \
    --region $region \
    --name ZS-CC-Test-GWLB-$random \
    --type gateway \
    --subnets $subnetid  2>&1 | grep -q 'LoadBalancerName' 
then
    echo "${red}FAILED. You do not have permissions to create an Elastic Load Balancer...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create an Elastic Load Balancer...${reset}"
    echo ""
fi

# Target Group
echo "Creating Test Target Group..."
if ! aws elbv2 create-target-group \
    --region $region \
    --name ZS-CC-Test-TG-$random \
    --protocol GENEVE \
    --port 6081 \
    --target-type ip \
    --vpc-id $vpcid  2>&1 | grep -q 'TargetGroupName' 
then
    echo "${red}FAILED. You do not have permissions to create a Target Group...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create a Target Group...${reset}"
    tgarn=$(aws elbv2 describe-target-groups --names "ZS-CC-Test-TG-$random" --query 'TargetGroups[*].[TargetGroupArn]' --output text)
    echo ""
fi

# GWLB (Dry Run)
echo "Creating Test GWLB Service..."
gwlbarn=$(aws elbv2 describe-load-balancers --names "ZS-CC-Test-GWLB-$random" --query 'LoadBalancers[*].[LoadBalancerArn]' --output text)
if ! aws ec2 create-vpc-endpoint-service-configuration \
    --region $region \
    --gateway-load-balancer-arns $gwlbarn \
    --acceptance-required \
    --dry-run 2>&1 | grep -q 'Request would have succeeded' 
then
    echo "${red}FAILED. You do not have permissions to create a GWLB Service...${reset}"
    echo ""
else
    echo "${blue}SUCCESS. You can create a GWLB Service...${reset}"
    echo ""
fi

echo "All Test Resource Creations Completed. Please check for any failures prior to deploying Zscaler Cloud Connectors..."
echo ""

# Delete the Test Resources
read -p "${purple}Press enter to delete all the test resources that were not dry runs...${reset}"
echo ""

echo "Deleting Test Target Group..."
echo ""
aws elbv2 delete-target-group \
    --region $region \
    --target-group-arn $tgarn

echo "Deleting Test Load Balancer..."
echo ""
aws elbv2 delete-load-balancer \
    --region $region \
    --load-balancer-arn $gwlbarn

echo "Deleting Test Instance Profile..."
echo ""
aws iam delete-instance-profile \
    --region $region \
    --instance-profile-name "ZscalerCCInstanceProfileTest-$random" 

echo "Deleting Test Lambda Permission..."
echo ""
aws lambda remove-permission \
    --region $region \
    --function-name ZS-CC-Test-Function-$random \
    --statement-id ZS-CC-Test-Lambda-Permission-$random

echo "Deleting Test Lambda Function..."
echo ""
aws lambda delete-function \
    --region $region \
    --function-name ZS-CC-Test-Function-$random

echo "Deleting Test IAM Role Policy Attachment..."
echo ""
aws iam delete-role-policy \
    --region $region \
    --role-name ZS-CC-Role-Test-$random \
    --policy-name ZS-CC-Test-Role-Policy-$random

echo "Deleting Test IAM Role..."
echo ""
 aws iam delete-role \
     --region $region \
     --role-name ZS-CC-Role-Test-$random

echo "${purple}All test resources deleted...${reset}"