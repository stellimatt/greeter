#bin/bash

# NOTE: upper-cased environment variables should be in the script executor's profile

app_name=greeter
repository_url=https://github.com/stellimatt/greeter.git
repository_branch=master # change to phase1 when ready
aws_region=${AWS_REGION:-us-east-1}
aws_vpc=${AWS_VPC_ID:-vpc-857a3ee2}
aws_subnets=${AWS_SUBNET_IDS:-subnet-c5a76a8c,subnet-3b233a06}
aws_azs=${AWS_AZS:-us-east-1c,us-east-1b}
aws_keypair=${AWS_KEYPAIR:-example.pem}
working_directory=.working_directory

rds_password=${RDS_PWD:-example123}
rds_username=${RDS_USER_NAME:-fred}

# pull source code:
rm -rf $working_directory
git clone --branch ${repository_branch} --depth 1 ${repository_url} $working_directory

# perform static analysis on the code
pushd $working_directory
  foodcritic -t ~FC001 pipelines/cookbooks/greeter
popd

stamp=$(date +%Y%m%d%H%M%s)

# run aws cli for cloudformation of RDS
#TODO
# look for RDS stack by name:
rds_stack_name="rds-${app_name}"
echo $(aws cloudformation describe-stacks --stack-name ${rds_stack_name} 2>/dev/null) > rds.tmp
stack_exists=$(cat rds.tmp | grep -i stackname | grep ${rds_stack_name})

if [ ":$stack_exists" == ":" ]; then
  aws cloudformation create-stack \
    --disable-rollback \
    --region ${aws_region} \
    --stack-name ${rds_stack_name} \
    --template-body https://stelligent-blog.s3.amazonaws.com/stelligent-labs/chefjson/templates/mysql-rds.template \
    --capabilities CAPABILITY_IAM \
    --tags \
      Key="application",Value=${app_name} \
      Key="branch",Value=${repository_branch} \
    --parameters \
      ParameterKey=VpcId,ParameterValue=${aws_vpc} \
      ParameterKey=AppName,ParameterValue=${app_name} \
      ParameterKey=DBSubnetGroupID,ParameterValue=${DB_SUBNET_GROUP:-test-subnet} \
      ParameterKey=DBInstanceIdentifier,ParameterValue=${rds_stack_name} \
      ParameterKey=DBName,ParameterValue=$(echo -n ${app_name} | sed 's/-//g') \
      ParameterKey=DBUsername,ParameterValue=${rds_username} \
      ParameterKey=DBPassword,ParameterValue=${rds_password} \
      ParameterKey=DBParameterGroupName,ParameterValue=${RDS_PARAM_GROUP:-default.mysql5.6}

  aws cloudformation wait stack-create-complete --stack-name ${rds_stack_name}
  echo $(aws cloudformation describe-stacks --stack-name ${rds_stack_name} 2>/dev/null) > rds.tmp
fi

db_instance_id=$(cat rds.tmp | jq '.Stacks[0].Outputs[] | select(.OutputKey == "DBInstanceId") | .OutputValue')
db_url=$(cat rds.tmp | jq '.Stacks[0].Outputs[] | select(.OutputKey == "DBEndpoint") | .OutputValue')
db_port=$(cat rds.tmp | jq '.Stacks[0].Outputs[] | select(.OutputKey == "DBPort") | .OutputValue')

git_statement="git clone --branch ${repository_branch} --depth 1 ${repository_url} /opt/${app_name}"

# run aws cli for cloudformation of ASG
asg_stack_name="${app_name}-${stamp}"
chef_json_key="${asg_stack_name}.json"

# push chef.json to s3
echo {} | jq ".run_list = [\"greeter\"] | .greeter = \
  {db_url: \"$db_url\", \
  db_name: \"$app_name\", \
  username: \"$rds_username\", \
  password: \"$rds_password\", \
  docroot: \"/var/www/${app_name}\"}" > chef.json

aws s3 cp chef.json s3://stelligent-labs/chefjson/jsons/$chef_json_key

aws cloudformation create-stack \
  --disable-rollback \
  --region ${aws_region} \
  --stack-name ${asg_stack_name} \
  --template-body https://s3.amazonaws.com/stelligent-blog/chefjson/templates/deploy-app.template \
  --capabilities CAPABILITY_IAM \
  --tags \
    Key="application",Value=${app_name} \
    Key="branch",Value=${repository_branch} \
  --parameters \
    ParameterKey=VpcId,ParameterValue=${aws_vpc} \
    ParameterKey=AppName,ParameterValue=${app_name} \
    ParameterKey=AWSKeyPair,ParameterValue=${aws_keypair} \
    ParameterKey=ASGSubnetIds,ParameterValue=\"${aws_subnets}\" \
    ParameterKey=ASGAvailabilityZones,ParameterValue=\"${aws_azs}\" \
    ParameterKey=ChefJsonKey,ParameterValue=${chef_json_key} \
    ParameterKey=GitStatement,ParameterValue=${git_statement}


aws cloudformation wait stack-create-complete --stack-name ${asg_stack_name}
