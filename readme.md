Capify Ec2
====================================================

capify-ec2 is used to generate capistrano namespaces using ec2 tags. 

eg: If you have three servers on amazon's ec2.

    server-1 Tag: Role => "web"
    server-2 Tag: Role => "db"
    server-3 Tag: Roles => "web, db"

Installing

    gem install capify-ec2

In your deploy.rb:

    require "capify-ec2/capistrano"
    ec2_roles :web

Will generate

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

Additionally

    require "capify-ec2/capistrano"
    ec2_roles :db

Will generate

    task :server-2 do
      role :db, {server-2 public dns fetched from Amazon}
    end

    task :server-3 do
      role :db, {server-3 public dns fetched from Amazon}
    end

    task :db do
      role :db, {server-2 public dns fetched from Amazon}
      role :db, {server-3 public dns fetched from Amazon}
    end    

Running

    cap web date

will run the date command on all server's tagged with the web role

Running

  cap server-1 register-instance -s loadbalancer=elb-1

will register server-1 to be used by elb-1

Running
  
  cap server-1 deregister-instance

will remove server-1 from whatever instance it is currently
registered against.

Running
  
  cap ec2_status

will list the currently running servers and their associated details 
(public dns, instance id, roles etc)

Running
  
  cap ssh -s i=1

will launch ssh using the user and port specified in your configuration.
The 'i' argument is the index of the server to ssh into. Use the 'ec2_status'
command to see the list of servers with their indices. If the 'i' argument
is omitted then the first instance will be used.

More options
====================================================

    ec2_roles {:name=>"web", :options=>{:cron=>"server-1"}}
  
Will generate

    task :server-1 do
      role :web, {server-1 public dns fetched from Amazon}, :cron=>true
    end

    task :server-3 do
      role :web, {server-1 public dns fetched from Amazon}
    end

    task :web do
      role :web, {server-1 public dns fetched from Amazon}, :cron=>true
      role :web, {server-3 public dns fetched from Amazon}
    end

Which is cool if you want a task like this in deploy.rb

    task :update_cron => :web, :only=>{:cron} do
      Do something to a server with cron on it
    end


ec2_roles :name=>:web, :options=>{ :default => true }

Will make :web the default role so you can just type 'cap deploy'. 
Multiple roles can be defaults so: 

ec2_roles :name=>:web, :options=>{ :default => true }
ec2_roles :name=>:app, :options=>{ :default => true }

would be the equivalent of 'cap app web deploy'

Ec2 config
====================================================

This gem requires 'config/ec2.yml' in your project.
The yml file needs to look something like this:

    	:aws_access_key_id: "YOUR ACCESS KEY"
    	:aws_secret_access_key: "YOUR SECRET"
    	:aws_params:
    	  :region: 'eu-west-1'
		  :load_balanced: true
		  :project_name: "YOUR APP NAME"

The :aws_params are optional.
If :load_balanced is set to true, the gem uses pre and post-deploy
hooks to deregister the instance, reregister it, and validate its
health.
:load_balanced only works for individual instances, not for roles.

The :project_name parameter is optional. It will limit any commands to 
running against those instances with a "Project" tag set to the value 
"YOUR APP NAME".

