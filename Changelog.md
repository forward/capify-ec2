## 1.2.6 (Mar 06, 2012)

Notes:

  - Minor refactoring to make the code clearer
  
Bugfixes:

  - Documentation showed whitespaces in Options and Roles, but they weren't supported in the code. (Thanks ennui2342)

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
