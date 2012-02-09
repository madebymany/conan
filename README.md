Conan the Deployer
==================

Conan was conceived and developed to facilitate the deployment of a Rails
application to one or more EC2 instances without the need for any additional
centralised infrastructure. It glues together Capistrano and Chef and some
common assumptions to make it easy to capture the environment of an application
in the source repository.

What it is
----------

* Some Capistrano extensions
* Template files and directories

What Conan does
---------------

Short version: it lets you set up a server and deploy your application in one line:

    cap production configure deploy

Longer version:

* It creates a `Capfile` and `config/deploy.rb` for Capistrano
* It adds some files
* It adds a Git submodule with Chef cookbooks
* It knows how to merge together JSON files describing servers and roles

Assumptions:

* You have a Rails 2.3.x or 3.x.x project that uses Bundler.
* You keep your project in a Git repository.
* You have staging and production servers (this can be changed).
* You have SSH access to some Ubuntu servers and can sign in and `sudo` as `ubuntu` (this is presently a hard requirement, but is not fundamental).

How to use it
-------------

    gem install conan
    cd /path/to/rails/app
    conan init

Follow the instructions to complete configuration: this mainly consists of
editing TODOs in newly added files. See the section *Roles and configuration*
below for more details.

To set up the server using Chef Solo, use:

    cap staging configure

And to deploy (including running migrations):

    cap staging deploy

Stages
------

The default configuration assumes that you have a staging and production server
(or servers), and that you deploy the `master` branch to staging, test staging,
and deploy the same branch to production. To achieve this, Conan tags your
deployments with `(stage name).last-deploy`. If a deployment succeeds, it is
tagged with `(stage name).last-successful-deploy`. A happy deployment path is thus:

    master                         => staging.last-deploy
    staging.last-deploy            => staging.last-successful-deploy
    staging.last-successful-deploy => production.last-deploy
    production.last-deploy         => production.last-successful-deploy

Roles and configuration
-----------------------

The concept of *roles* is fundamental to Conan. `config/servers.json` describes
the available servers and their roles, whilst `deploy/chef/dna/*.json`
specifies the configuration specific to each role. The stage (`staging`,
`production`, etc.) can be considered a special case of role for practical
purposes.

Here is an example `config/servers.json`:

    {
      "staging": {
        "ec2-A-A-A-A.compute-1.amazonaws.com": {
          "roles": ["app", "db", "staging"],
          "alias": "staging"
        }
      },
      "production": {
        "ec2-B-B-B-B.compute-1.amazonaws.com": {
          "roles": ["app", "db", "production"],
          "alias": "app1"
        },
        "ec2-C-C-C-C.compute-1.amazonaws.com": {
          "roles": ["app", "production"],
          "alias": "app2"
        }
      }
    }

In this scenario, the configuration for the staging server will be produced by merging:

* `base.json`
* `app.json`
* `db.json`
* `staging.json`


Furthermore, this server will have the `app` and `db` roles in Capistrano, with
the usual meanings: the application will be deployed on this server, and the
database migrations will be run.
