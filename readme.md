#TODO: Note that load_balanced can only be used if an instance is in a single ELB.
#TODO: Document the use of load_balanced with rolling deploy.


## Capify-EC2

Capify-EC2 is used to generate Capistrano namespaces and tasks from Amazon EC2 instance tags, dynamically building the list of servers to be deployed to.


### Installation

    gem install capify-ec2

or add the gem to your project's Gemfile.

You will need to create a YML configuration file at 'config/ec2.yml' that looks like the following:

```ruby
:aws_access_key_id: "YOUR ACCESS KEY"
:aws_secret_access_key: "YOUR SECRET"
:aws_params:
  :region: 'eu-west-1'
:load_balanced: true
:project_tag: "YOUR APP NAME"
```

Finally, add the gem to your 'deploy.rb':

```ruby
require "capify-ec2/capistrano"
```



#### Configuration

Note: 'aws_access_key_id', 'aws_secret_access_key', and 'region' are required. Other settings are optional.

* :project_tag

  If this is defined, Capify-EC2 will only create namespaces and tasks for the EC2 instances that have a matching 'Project' tag. By default, all instances available to the configured AWS access key will be used.

  It is possible to include multiple projects simultaneously by using the :project_tags parameter, like so: 

  ```ruby
  :project_tags: 
    - "YOUR APP NAME"
    - "YOUR OTHER APP NAME"
   ```

* :load_balanced

  When ':load_balanced' is set to 'true', Capify-EC2 uses pre and post-deploy hooks to deregister the instance from an associated Elastic Load Balancer, perform the actual deploy, then finally reregister with the ELB and validated the instance health.
  Note: This options only applies to deployments made to an individual instance, using the command 'cap INSTANCE_NAME_HERE deploy' - it doesn't apply to roles.



#### EC2 Tags

You will need to create instance tags using the AWS Management Console or API, to further configure Capify-EC2. The following tags are used:

* Tag 'Project'

  Used with the ':project_tag' option in 'config/ec2.yml' to limit Capify-EC2's functionality to a subset of your instances.

* Tag 'Roles'

  A comma seperated list of roles that will be converted into Capistrano namespaces, for example 'app,workers', 'app,varnish,workers', 'db' and so on.

* Tag 'Options'

  A comma seperated list of options which will be defined as 'true' for that instance. See the 'Options' section below for more information on their use.
  task :bob, :only => {:option_nmame => true}
  on_no_matching_servers => :continue
  "one of those ten is cron" etc.



### Usage

In our examples, imagine that you have three servers on EC2 defined as follows:

    server-1 Tags: Name: "server-1", Roles: "web", Options: "cron,resque"
    server-2 Tags: Name: "server-2", Roles: "db"
    server-3 Tags: Name: "server-3", Roles: "web,db,app"

#### Single Roles

You need to add a call to 'ec2_roles' in your 'deploy.rb', like so:

```ruby
ec2_roles :web
```

This will generate the following tasks:

```ruby
task :server-1 do
  role :web, SERVER-1_EC2_PUBLIC_DNS_HERE, :cron=>true, :resque=>true
end

task :server-3 do
  role :web, SERVER-3_EC2_PUBLIC_DNS_HERE
end

task :web do
  role :web, SERVER-1_EC2_PUBLIC_DNS_HERE, :cron=>true, :resque=>true
  role :web, SERVER-3_EC2_PUBLIC_DNS_HERE
end
```

Note that there are no tasks created for 'server-2', as it does not have the role 'web'. If we were to change the 'ec2_roles' definition in your 'deploy.rb' to the following:

```ruby
ec2_roles :db
```

Then we will instead see the following tasks generated:

```ruby
task :server-2 do
  role :db, SERVER-2_EC2_PUBLIC_DNS_HERE
end

task :server-3 do
  role :db, SERVER-3_EC2_PUBLIC_DNS_HERE
end

task :db do
  role :db, SERVER-2_EC2_PUBLIC_DNS_HERE
  role :db, SERVER-3_EC2_PUBLIC_DNS_HERE
end
```


#### Multiple Roles

If you want to create tasks for servers using multiple roles, you can call 'ec2_roles' multiple times in your 'deploy.rb' as follows:

```ruby
ec2_roles :web
ec2_roles :db
```

Which would generate the following tasks:

```ruby
task :server-1 do
  role :web, SERVER-1_EC2_PUBLIC_DNS_HERE, :cron=>true, :resque=>true
end

task :server-2 do
  role :db, SERVER-2_EC2_PUBLIC_DNS_HERE
end

task :server-3 do
  role :web, SERVER-3_EC2_PUBLIC_DNS_HERE
  role :db, SERVER-3_EC2_PUBLIC_DNS_HERE
end

task :web do
  role :web, SERVER-1_EC2_PUBLIC_DNS_HERE
  role :web, SERVER-3_EC2_PUBLIC_DNS_HERE
end

task :db do
  role :db, SERVER-2_EC2_PUBLIC_DNS_HERE, :cron=>true, :resque=>true
  role :db, SERVER-3_EC2_PUBLIC_DNS_HERE
end
```



#### Role Variables

You can define custom variables which will be set as standard Capistrano variables within the scope of the role you define them one, for example:

```ruby
ec2_roles {:name=>"web", :variables => {:rails_env => 'staging'}}
```

In this case, instances that that are tagged with the 'web' role will have the custom variable 'rails_env' available to them in any tasks they use. The following tasks would be generated:

```ruby
task :server-1 do
  role :web, SERVER-1_EC2_PUBLIC_DNS_HERE, :cron=>true, :resque=>true, :rails_env=>'staging'
end

task :server-3 do
  role :web, SERVER-3_EC2_PUBLIC_DNS_HERE
end

task :web do
  role :web, SERVER-1_EC2_PUBLIC_DNS_HERE, :cron=>true, :resque=>true, :rails_env=>'staging'
  role :web, SERVER-3_EC2_PUBLIC_DNS_HERE, :rails_env=>'staging'
end
```



#### Options

##### Via EC2 Tags

As mentioned in the 'EC2 Tags' section, creating an 'Options' tag on your EC2 instances will define those options as 'true' for the associated instance. This allows you to refine your capistrano tasks.
For example, if we had the following group of instances in EC2:

    server-A Tags: Name => "server-A", Roles => "web"
    server-B Tags: Name => "server-B", Roles => "web"
    server-C Tags: Name => "server-C", Roles => "web", Options => "worker"

You could then create a task in your 'deploy.rb' that will only be executed on the worker machine, like so:

```ruby
task :reload_workers => :web, :only=>{:worker} do
  # Do something to a server with cron on it
end
```

##### Via Role Definitions

As well as defining Options at an instance level via EC2 tags, you can define an Option in your 'deploy.rb' at the same time as defining the role, as follows:

```ruby
ec2_roles {:name=>"web", :options=>{:worker=>"server-C"}}
```

In this case, you set the value of ':worker' equal to the instance name you want to be a worker.



#### Deploying

Once you have defined the various roles used by your application, you can deploy to it as you normally would a namespace, for example if you define the following in your 'deploy.rb':

```ruby
ec2_roles :web
ec2_roles :app
```

You can deploy to just the 'web' instances like so:

```ruby
cap web deploy
```

If you've defined multiple roles, you can deploy to them all by chaining the tasks, like so:

```ruby
cap web app deploy
```



##### Default Deploys

You can set a role as the default so that it will be included when you run 'cap deploy' without specifying any roles, for example in your 'deploy.rb':

```ruby
ec2_roles :name=>"web", :options => {:default=>true}
```

Then run:

```ruby
cap deploy
```

You can set multiple roles as defaults, so they are all included when you run 'cap deploy', like so:

```ruby
ec2_roles :name=>"web", :options => {:default=>true}
ec2_roles :name=>"db", :options => {:default=>true}
```



#### Rolling Deployments

This feature allows you to deploy your code to instances one at a time, rather than simultaneously. This becomes useful for more complex applications that may take longer to startup after a deployment. Capistrano will perform a full deploy (including any custom hooks) against a single instance, optionally perform a HTTP healthcheck against the instance, then proceed to the next instance if deployment was successful.

##### Usage

To use the rolling deployment feature without a healthcheck, simple run your deployments with the following command:

```ruby
cap rolling_deploy
```

You can restrict the scope of the rolling deploy by targetting one or more roles like so:

```ruby
cap web rolling_deploy
```

```ruby
cap web db rolling_deploy
```

##### Usage with Healthchecks

When defining a role with the 'ec2_role' command, if you configure a healthcheck for that role as follows, it will automatically be used during the rolling deployment:

```ruby
ec2_roles :name => "web",
          :variables => { 
            :healthcheck => {
              :path   => '/status',
              :port   => 80, 
              :result => 'OK'
            }
          }
```

In this example, the following URL would be generated:

```
http://EC2_INSTANCE_PUBLIC_DNS_HERE:80/status
```

And the contents of the page at that URL must match 'OK' for the healthcheck to pass. If unsuccessful, the healthcheck is repeated every second, until a timeout of 60 seconds is reached, at which point the rolling deployment is aborted, and a progress summary displayed.

The default timeout is 60 seconds, which can be overridden by setting ':timeout' to a custom value in seconds. The protocol used defaults to 'http://', however you can switch to 'https://' by setting ':https' equal to 'true'. For example:

```ruby
ec2_roles :name => "web",
          :variables => { 
            :healthcheck => {
              :path   => '/status',
              :port   => 80, 
              :result => 'OK'
              :https   => true, 
              :timeout => 10
            }
          }
```

Sets a 10 second timeout, and performs the health check over HTTPS.



#### Viewing All Instances

The following command will generate a listing of all instances that match your configuration (projects and roles), along with their associated details:

```ruby
cap ec2:status
```



#### Managing Load Balancers

You can use the following commands to deregister and reregister instances in an Elastic Load Balancer.

```ruby
cap SERVER_NAME_HERE ec2:deregister_instance
```

```ruby
cap SERVER_NAME_HERE ec2:register_instance -s loadbalancer=ELB_NAME_HERE
```

You need to specify the ELB when reregistering an instance, but not when deregistering. This can also be done automatically using the ':load_balanced' setting (see the 'Configuration' section above).



#### Connecting to an Instance via SSH

Using the 'cap ec2:ssh' command, you can quickly connect to a specific instance, by checking the listing from 'ec2:status' and using the instance number as a parameter, for example:

```ruby
cap ec2:ssh 1
```

will attempt to connect to instance number 1 (as shown in 'ec2:status'), using the public DNS address provided by AWS.



#### Other Commands

Running the following command:

```ruby
cap ec2:date
```

Will execute the 'date' command on all instances that match your configuration (projects and roles). You can limit this further by using a role, for example:

```ruby
cap web ec2:date
```

Will restrict the 'date' command so it is only run on instances that are tagged with the 'web' role. You can chain many roles together to increase the scope of the command:

```ruby
cap web db ec2:date
```

##### Cap Invoke

You can use the standard Capistrano 'invoke' task to run an arbitrary command on your instances, for example:

```ruby
cap COMMAND='uptime' invoke
```

Will run the 'uptime' command on all instances that match your configuration (projects and roles). As with the 'ec2:date' command, you can further limit this by using a role, like so:

```ruby
cap web COMMAND='uptime' invoke
```

You can also chain many roles together to increase the scope of the command:

```ruby
cap web db COMMAND='uptime' invoke
```

##### Cap Shell

You can use the standard Capistrano 'shell' task to open an interactive terminal session with your instances, for example:

```ruby
cap shell
```

Will open an interactive terminal on all instances that match your configuration (projects and roles). You can of course limit the scope of the shell to a certain role or roles like so:

```ruby
cap web shell
```

```ruby
cap web db shell
```



### Development

Source hosted at [GitHub](http://github.com/forward/capify-ec2).
Report Issues/Feature requests on [GitHub Issues](http://github.com/forward/capify-ec2/issues).

#### Note on Patches/Pull Requests

 * Fork the project.
 * Make your feature addition or bug fix.
 * Add tests for it. This is important so I don't break it in a
   future version unintentionally.
 * Commit, do not mess with rakefile, version, or history.
   (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
 * Send me a pull request. Bonus points for topic branches.

### Copyright

Copyright (c) 2011, 2012, 2013 Forward. See [LICENSE](https://github.com/forward/capify-ec2/blob/master/LICENSE) for details.