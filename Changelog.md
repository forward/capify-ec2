## 1.5.1 (Sep 2, 2013)

Bugfixes:

  - Fixed an exception when using the 'ec2:status' command with EC2 instances which have empty 'name' tags.

## 1.5.0 (Aug 20, 2013)

Contains the changes from v1.5.0.pre to v1.5.0.pre3.

## 1.5.0.pre3 (Aug 6, 2013)

Features:

  - Capify-EC2 will now use the 'ssh_options[:keys]' setting in your 'deploy.rb' when connecting to an instance using the 'ec2:ssh' command.

Bugfixes:

  - Fixed an exception when using the 'ec2:ssh' and 'ec2:status' commands with stages.

## 1.5.0.pre2 (Jul 23, 2013)

Bugfixes:

  - Fixed a regression where Capify-EC2 wasn't pulling in configuration from anything except for 'ec2.yml'.

## 1.5.0.pre (Jul 19, 2013)

Features:

  - Added Support for the [Capistrano Multistage Extension](https://github.com/capistrano/capistrano/wiki/2.x-Multistage-Extension).
  - Allow the use of IAM roles to authenticate with AWS, rather than an access key id and secret access key.

Bugfixes:

  - Fixed an issue executing cap tasks on individual instances.

## 1.4.11 (Jun 13, 2013)

Features:

  - When performing a rolling deployment healthcheck over HTTPS, SSL peer verification is disabled, as the EC2 instance public DNS will not match the SSL certificate hostname.

## 1.4.10 (Jun 13, 2013)

Bugfixes:

  - Require 'net/http' for the rolling deployment healthcheck.

## 1.4.9 (May 17, 2013)

Bugfixes:

  - Determine and set the real SCM revision explicitly, before beginning the rolling deployment. This is to prevent changes made to SCM during deployment from being inadvertently released.

## 1.4.8 (May 17, 2013)

Features:

  - The EC2 instance tag used to determine instance Project can now be customised. Defaults to 'Project' if this setting is ommited.
  - If any project tags are being used, they are now displayed when running the 'ec2:status' command.

## 1.4.7 (May 16, 2013)

Features:

  - Added the ability to load AWS credentials from the Fog configuration file, rather than from the 'ec2.yml' file. Refer to the Fog documentation for details on specifying AWS credentials.
  - Improved error handling when no AWS credentials are found by any supported method.

## 1.4.6 (May 15, 2013)

Features:

  - Added the ability to specify AWS credentials as environment variables rather than in the 'ec2.yml' file.

## 1.4.5 (May 15, 2013)

Bugfixes:

  - Fixed an issue where instances would be removed from their ELB during rolling deployment, even if --dry-run was set.

## 1.4.4 (May 15, 2013)

Features:

  - The EC2 instance tag used to determine instance options can now be customised. Defaults to 'Options' if this setting is ommited.
  - If the 'Roles' or 'Options' tags are customised, this custom text will be used as the appropriate column headers in the 'ec2:status' command.

Bugfixes:

  - Fix some issues with customised 'Roles' tags not being respected in all situations.

## 1.4.3 (Apr 19, 2013)

Summary of the changes merged from the 'rolling_deploy' branch, from v1.4.0.pre1 to v1.4.3.pre7.

Features:

  - New rolling deployment mode, allows you to deploy to your instances in serial, rather than in parallel, with an option to perform a healthcheck before proceeding to the next instance. For more information on this feature, check out the [documentation](readme.md#rolling-deployments).
  - Allowed the expected result for the rolling deployment healthcheck to be specified as a regex or an array in addition to a string.
  - Added the ability to automatically deregister and reregister an instance from its associated Elastic Load Balancer when using the rolling deployment feature.
  - Added the ability to run multiple healthchecks per role by specifying an array of them when defining the role.
  - Minimum Capistrano version required set to v2.14 or greater. This fixes several issues, including an exception being thrown when a task was limited to certain roles, which weren't specified during deployment. For example, a task limited to ':roles => [:web]' would raise an exception if you tried to run 'cap db deploy', as no roles would match.
  - The documentation has been rewritten to make it clearer how to use Capify-EC2 and what the available options are.

Bugfixes:

  - Instance options are now properly retained when performing a rolling deployment.
  - Fixed a range of errors in the documentation.
  - Error handling improved when working with the 'ec2:ssh' command.
  - Fixed an issue which was preventing the main deployment task from being executed during a rolling deployment.
  - Fixed an issue with healthcheck expected response output.
  - Exit with status 1 when encountering rolling deployment errors, afer displaying the deployment status overview.
 
## 1.4.3.pre7 (Apr 11, 2013)

Bugfixes:

  - Exit with status 1 when encountering rolling deployment errors, afer displaying the deployment status overview.

## 1.4.3.pre6 (Apr 9, 2013)

Bugfixes:

  - Fixed an issue with healthcheck expected response output.

## 1.4.3.pre5 (Apr 9, 2013)

Features:
  
  - Allowed the expected result for the rolling deployment healthcheck to be specified as a regex or an array in addition to a string.

Bugfixes:

  - Fixed an issue which was preventing the main deployment task from being executed during a rolling deployment.

## 1.4.2.pre4 (Mar 28, 2013)

Features:

  - Added the ability to run multiple healthchecks per role by specifying an array of them when defining the role.
  - Improved readability of output from rolling deployments.

Bugfixes:

  - Error handling improved when working with the 'ec2:ssh' command.


## 1.4.1.pre3 (Mar 1, 2013)

Features:

  - Added the ability to automatically deregister and reregister an instance from its associated Elastic Load Balancer when using the rolling deployment feature.

Bugfixes:

  - Instance options are now properly retained when performing a rolling deployment.
  - Fixed a range of errors in the documentation.

## 1.4.0.pre2 (Feb 15, 2013)

Features:

  - Minimum Capistrano version required set to v2.14 or greater. This fixes several issues, including an exception being thrown when a task was limited to certain roles, which weren't specified during deployment. For example, a task limited to ':roles => [:web]' would raise an exception if you tried to run 'cap db deploy', as no roles would match.

## 1.4.0.pre1 (Feb 15, 2013)

Features:

  - New rolling deployment mode, allows you to deploy to your instances in serial, rather than in parallel, with an option to perform a healthcheck before proceeding to the next instance. For more information on this feature, check out the [documentation](readme.md#rolling-deployments).
  - The documentation has been rewritten to make it clearer how to use Capify-EC2 and what the available options are.

## 1.3.7 (Jan 20, 2013)

  - Make the behaviour for passing hash/filename consistent
  - Fix ec2_role when role_name_or_hash is not a hash.

## 1.3.6 (Jan 17, 2013)

Bugfixes:

  - Fix ec2:status alignment issues when the column contents are smaller than the column headings.

## 1.3.5 (Jan 11, 2013)

Features:

  - Updated output from ec2:status, improving readability, and improving handling of instance attributes that vary in size.

Bugfixes:

  - Region role creation fixed, so that you can deploy just to instances in specific regions again (i.e. cap us-east-1 deploy).
  - Fixed 'already initialized constant' warning which may be shown to users running some versions of Ruby 1.8.

## 1.3.0 to 1.3.4

Sorry, release notes were not added for these versions.

## 1.2.9 (June 29, 2012)

Bugfixes:

  - No longer throws an error when a server has no name.

## 1.2.8 (May 16, 2012)

Notes:

  - Minor refactoring to make the code clearer
  - Updated code to allow commas and any amount of whitespace between options and roles (Thanks ennui2342)
  - Updated documentation to reflect multiple correct formats.
  
Bugfixes:

## 1.2.5 (Jan 26, 2012)

Features:

  - Added ability to connect to VPC instances. Very basic functionality.

## 1.2.4 (Jan 24, 2012)

Features:

  - Remove handling of singular 'role.' It was causing unnecessary difficulties.

Bugfixes:

  - Options flag not properly recognized.
  - Fixed longstanding issue of handling comma-separated roles

## 1.2.2 (Dec 05, 2011)

Bugfixes:

  - Mismatch between ec2:status and ec2:ssh lead to connecting to the wrong server.

## 1.2.1 (Dec 02, 2011)

Bugfixes:

  - Regression bug fixed. Projects weren't being filtered properly.
  
## 1.2.0 (Dec 02, 2011)

Features:

  - Much improved performance
  - US-West-1 now available (fog upgrade)
  
## 1.1.16 (Sep 23, 2011)

Features:

  - Added 'option' handling. Allows users to move cap options ('cron,' 'db,' 'resque,' etc.) to 'Option' field at AWS.

## 1.1.15 (Sep 02, 2011)

Bugfixes:

  - Fixed problem with ec2:ssh task not terminating properly

## 1.1.14 (Aug 24, 2011)

Bugfixes:

  - Fixed chaining of tasks
  - Fixed handling of defaults and their interactions with specified tasks (particularly across regions)
  
Features:

  - Moved the following to ec2 namespace to make it clearer what's part of the gem
    - status (formerly ec2_status)
    - register_instance
    - deregister_instance
    - date
    - server_names


## 1.1.13 (Aug 10, 2011)

Bugfixes:

  - Obscure bug fixed. Multiple roles where some instances weren't in all roles would throw an error if you tried to tell a task to only fire when particular roles were deployed to. This bug only fired if you performed your action on a single instance (cap server deploy).

## 1.1.12 (Aug 09, 2011)

Features:

  - Add ability to deploy to all similar roles in a region
  - Add ability to cap ssh <ec2 index number>
  - Add ability to cap ssh <instance name>
  - Froze dependencies to known working gems
  - Allow cap deploy with a server set as default
  - Added descriptions (try cap -T)
  - Fix gem dependencies for cap ec2_status
  - Allows registering and deregistering of instances with an ELB
  - Servers can have Role or Roles on ec2


Bugfixes:

  - Allow options to be passed to ec2_roles
  - Deregister and register server with elb
  - Fixed server_names directive to display case insensitive names. Matches with ssh
  - Defaults no longer break options
