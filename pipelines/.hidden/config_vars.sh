#bin/bash
export AWS_REGION="us-east-1"
export AWS_SUBNET_IDS="subnet-c5a76a8c,subnet-3b233a06"
export AWS_VPC_ID="vpc-857a3ee2"
export AWS_AZS="us-east-1c,us-east-1b"
export AWS_KEYPAIR="matt-labs"
export RDS_PWD="example123"
export RDS_USER_NAME="fred"

export DEPLOY_RDS_TEMPLATE="config/rds.cfn"
export DB_SUBNET_GROUP="matt-test"
export RDS_PARAM_GROUP="default.mysql5.6"

export DEPLOY_TEMPLATE="config/deploy-app.cfn"
