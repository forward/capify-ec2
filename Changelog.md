## 1.1.14 (Aug 24, 2011)

Bugfixes:

  - Fixed chaining of tasks
  
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
