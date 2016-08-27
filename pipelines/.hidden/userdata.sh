#!/bin/bash
apt-get update
apt-get install git awscli -y

git clone %{GitUrl} -b %{GitBranch} --depth 1 /opt/%{AppName}

if [ ":" == ":$(dpkg -l | grep chefdk)" ]; then
  pushd /tmp
  wget --quiet https://packages.chef.io/stable/ubuntu/12.04/chefdk_0.16.28-1_amd64.deb
  dpkg -i chefdk_0.16.28-1_amd64.deb
  mkdir /tmp/cookbooks
fi

pushd /opt/%{AppName}/pipelines/cookbooks/%{AppName}
berks -d vendor /tmp/cookbooks | tee /tmp/debug_berks.log

aws s3 cp --region %{AWS::Region} s3://stelligent-blog/chefjson/jsons/%{ChefJsonKey} /tmp/chef.json

echo 'cookbook_path ["/tmp/cookbooks", "/opt/%{AppName}/pipelines/cookbooks"]' > /tmp/solo.rb

chef-solo -c /tmp/solo.rb -j /tmp/chef.json
