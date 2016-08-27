CloudFormation {
  application_name = external_parameters.fetch(:application_name, 'greeter')

  Description "Creates a #{application_name} stack"

  Parameter(:VpcId) {
    Type 'AWS::EC2::VPC::Id'
    Description "Existing VPC ID to use"
  }

  Parameter(:GitUrl) {
    Type String
    Description "git url"
  }

  Parameter(:GitBranch) {
    Type String
    Description "git branch to use"
  }

  Parameter(:SecurityGroupPort) {
    Type String
    Description "port the application runs on"
  }

  Parameter(:ChefJsonKey) {
    Type String
    Description "name of the file the chef_json has in S3"
  }

  Parameter(:ASGImageId) {
    Type 'AWS::EC2::Image::Id'
    Description "Existing VPC ID to use"
    Default('ami-d90d92ce')
  }

  Parameter(:ASGInstanceType) {
    Type 'String'
    Description "Existing VPC ID to use"
    Default('t2.micro')
  }

  Parameter(:AppName) {
    Type 'String'
    Description "Name for application"
  }

  Parameter(:AWSKeyPair) {
    Type 'AWS::EC2::KeyPair::KeyName'
    Description "EC2 Keypair"
  }

  Parameter(:ASGSubnetIds) {
    #Type 'List<AWS::EC2::Subnet::Id>'
    Type 'CommaDelimitedList'
    Description "The subnets the ELB will direct traffic to"
  }

  Parameter(:ASGAvailabilityZones) {
    #Type 'List<AWS::EC2::AvailabilityZone::Name>'
    Type 'CommaDelimitedList'
    Description "The AZs the AutoScaling group will deploy to"
  }

  EC2_SecurityGroup(:securityGroup) {
    GroupDescription 'Load balancer & autoscaling group security ingress/egress'
    VpcId( Ref(:VpcId) )
    SecurityGroupIngress [
      {
        IpProtocol: 'tcp',
        FromPort: Ref(:SecurityGroupPort),
        ToPort: Ref(:SecurityGroupPort),
        CidrIp: '0.0.0.0/0'
      }
    ]

  }

  ElasticLoadBalancing_LoadBalancer(:loadBalancer) {
    ConnectionDrainingPolicy {
      Enabled(true)
      Timeout(300)
    }
    CrossZone true
    HealthCheck {
      Target(FnJoin('', ['HTTP:', Ref(:SecurityGroupPort), '/']))
      HealthyThreshold(3)
      UnhealthyThreshold(5)
      Interval(90)
      Timeout(60)
    }
    Listeners [
      Listener {
        LoadBalancerPort(Ref(:SecurityGroupPort))
        InstancePort(Ref(:SecurityGroupPort))
        Protocol('TCP')
      }
    ]
    SecurityGroups [ Ref(:securityGroup)]
    Subnets( Ref(:ASGSubnetIds) )
    Scheme('internal')
  }

  IAM_Role(:instanceRole) {
    AssumeRolePolicyDocument(JSON.parse(IO.read(File.expand_path('../assume-role-policy.json', __FILE__))))
    Path '/'
    Policies [
      {
        :PolicyName => "#{application_name}-policy",
        :PolicyDocument => JSON.parse(IO.read(File.expand_path('../service-policy.json', __FILE__)))
      }
    ]
  }

  IAM_InstanceProfile(:instanceProfile) {
    Path('/')
    Roles( [ Ref(:instanceRole) ] )
  }


  AutoScaling_LaunchConfiguration(:launchConfig) {
    AssociatePublicIpAddress false
    IamInstanceProfile Ref(:instanceProfile)
    ImageId( Ref(:ASGImageId) )
    InstanceType( Ref(:ASGInstanceType) )
    KeyName( Ref(:AWSKeyPair) )
    SecurityGroups( [Ref(:securityGroup)] )
    UserData FnBase64(FnFormat(
      IO.read(File.expand_path('../userdata.sh', __FILE__))
    ))
  }

  AutoScaling_AutoScalingGroup(:autoScalingGroup) {
    AvailabilityZones( Ref(:ASGAvailabilityZones) )
    LaunchConfigurationName Ref(:launchConfig)
    LoadBalancerNames([ Ref(:loadBalancer) ])
    HealthCheckGracePeriod 300
    HealthCheckType 'ELB'
    MaxSize(3)
    MinSize(1)
    VPCZoneIdentifier( Ref(:ASGSubnetIds) )
    CreationPolicy('ResourceSignal',
      {
        Count: '1',
        Timeout: 'PT10M'
      }
    )
  }

  AutoScaling_ScalingPolicy(:scaleUpPolicy) {
    AutoScalingGroupName Ref(:autoScalingGroup)
    AdjustmentType('ChangeInCapacity')
    Cooldown(300)
    ScalingAdjustment('3')
  }

  CloudWatch_Alarm(:alarmHigh) {
    AlarmDescription 'Scale-up if CPU > 75% for 1 minutes'
    MetricName 'CPUUtilization'
    Namespace 'AWS/EC2'
    Statistic 'Average'
    Period '60'
    EvaluationPeriods '1'
    Threshold '75'
    AlarmActions [ Ref(:scaleUpPolicy) ]
    Dimensions [
      Dimension {
        Name 'AutoScalingGroupName'
        Value Ref(:autoScalingGroup)
      }
    ]
    ComparisonOperator 'GreaterThanThreshold'
  }

  AutoScaling_ScalingPolicy(:scaleDownPolicy) {
    AutoScalingGroupName Ref(:autoScalingGroup)
    AdjustmentType('ChangeInCapacity')
    Cooldown(600)
    ScalingAdjustment('-1')
  }

  CloudWatch_Alarm(:alarmLow) {
    AlarmDescription 'Scale-down if CPU < 30% for 5 minutes'
    MetricName 'CPUUtilization'
    Namespace 'AWS/EC2'
    Statistic 'Average'
    Period '300'
    EvaluationPeriods '1'
    Threshold '30'
    AlarmActions [ Ref(:scaleDownPolicy) ]
    Dimensions [
      Dimension {
        Name 'AutoScalingGroupName'
        Value Ref(:autoScalingGroup)
      }
    ]
    ComparisonOperator 'LessThanThreshold'
  }

  Output(:DNSName, FnGetAtt('loadBalancer','DNSName'))
}
