#!/bin/bash

# git clone greeter
git clone git://github.com/stellimatt/greeter /opt/greeter

#install chefdk
if [ ":" == ":$(dpkg -l | grep chefdk)" ]; then
  pushd /tmp
  wget --quiet https://packages.chef.io/stable/ubuntu/12.04/chefdk_0.16.28-1_amd64.deb
  dpkg -i chefdk_0.16.28-1_amd64.deb
  mkdir /tmp/cookbooks
fi

pushd /opt/greeter/cookbooks/greeter
berks vendor /tmp/cookbooks

cat > /tmp/chef.json <<CHEFJSON
{
  "run_list": [
    "greeter"
  ],
  "greeter": {
    "db_url": "%{DbUrl}",
    "db_name": "%{DbName}",
    "username": "%{DbUsername}",
    "password": "%{DbPassword}",

    "docroot": "%{DocRoot}",
    "server_name": "%{}"
  }
}
CHEFJSON

cat > /tmp/solo.rb <<SOLO
	cookbook_path ['/tmp/cookbooks', '/opt/greeter/cookbooks']
SOLO


chef-solo -c /tmp/solo.rb -j /tmp/chef.json
