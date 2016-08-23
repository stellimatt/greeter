#!/bin/bash

# git clone greeter
# pushd greeter
if [ ":" == ":$(dpkg -l | grep chefdk)" ]; then
pushd /tmp
wget --quiet https://packages.chef.io/stable/ubuntu/12.04/chefdk_0.16.28-1_amd64.deb
dpkg -i chefdk_0.16.28-1_amd64.deb
mkdir /tmp/coobkooks
fi

pushd /vagrant/cookbooks/greeter
berks vendor /tmp/cookbooks

cat > /tmp/chef.json <<CHEFJSON
{
  "run_list": [
    "greeter"
  ],
  "greeter": {
    "username": "blog",
    "password": "blog",
    "server_name": "blogger",
    "docroot": "/var/www/html/index.html",
    "db_url": "localhost"
  }
}
CHEFJSON

cat > /tmp/solo.rb <<SOLO
	cookbook_path ['/tmp/cookbooks', '/vagrant/cookbooks']
SOLO


chef-solo -c /tmp/solo.rb -j /tmp/chef.json

