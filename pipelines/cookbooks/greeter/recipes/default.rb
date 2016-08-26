include_recipe "apt"
include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "apache2::mod_php5"
include_recipe "apache2"

apache_site "default" do
  enable true
end

web_app 'greeter' do
  template 'site.conf.erb'
  docroot node[:greeter][:docroot]
  server_name node[:greeter][:server_name]
end

cookbook_file "/tmp/db.seed" do
  source 'db.seed'
  owner 'root'
  group 'root'
  mode '755'
end

execute "seed database" do
  command "mysql -u #{node[:greeter][:username]} -p#{node[:greeter][:password]} -h #{node[:greeter][:db_url]} #{node[:greeter][:db_name]} < /tmp/db.seed"
  cwd "/var/www/greeter"
end

template "#{node[:greeter][:docroot]}/index.php" do
  source 'index.php.erb'
  owner 'www-data'
  group 'www-data'
  mode '755'
end
