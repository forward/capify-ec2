Capify Ec2
====================================================

capify-ec2 is used to generate capistrano namespaces using ec2 tags. 

eg: If you have three servers on amazon's ec2.

server-1 Tag: Role => "web"
server-2 Tag: Role => "db"
server-3 Tag: Role => "web"

In your deploy.rb:

    require "capify-ec2/capistrano"
    ec2_roles :web

Will generate;

    task :server-1 do
      role :web, {server-1 public dns fetched from Amazon}
    end
    
    task :server-3 do
      role :web, {server-1 public dns fetched from Amazon}
    end
    
    task :web do
      role :web, {server-1 public dns fetched from Amazon}
      role :web, {server-3 public dns fetched from Amazon}
    end


    ec2_roles :db

Will generate;

    task :server-2 do
      role :web, {server-2 public dns fetched from Amazon}
    end
    
    task :db do
      role :db, {server-2 public dns fetched from Amazon}
    end

Running

    cap web date

will run the date command on all server's tagged with the web role

This gem requires 'config/ec2.yml' in your project.
The yml file needs to look something like this:

    	:aws_access_key_id: "YOUR ACCESS KEY"
    	:aws_secret_access_key: "YOUR SECRET"
    	:aws_params:
    	  :region: 'eu-west-1'
	
The :aws_params are optional.