#!/bin/bash -e

CC="https://aws.amazon.com/marketplace/pp/prodview-cvzx4oiv7oljm"
MARKETPLACE_URL_REGEXP="^https://aws.amazon.com/marketplace/pp/prodview-cvzx4oiv7oljm"
MARKETPLACE_HTML_PRODUCTID_REGEXP="/marketplace/fulfillment\?productId=([a-f0-9-]+)"

# fetch product ID from marketplace page source
if [[ ! $(curl --silent "$CC") =~ $MARKETPLACE_HTML_PRODUCTID_REGEXP ]]; then
	exitError "Unable to extract product ID from marketplace page. Please try again..."
fi

# list available AMI entities associated with marketplace product ID
aws ec2 describe-images \
	--filters "Name=name,Values=*-${BASH_REMATCH[1]}-*" \
	--output text \
	--query "reverse(sort_by(Images,&CreationDate))[].[join(':',[ImageId,CreationDate,Description])]" \
	--region us-east-1