# Puppet Provisioning
A collection of handy scripts to help you get up and running with Puppet as quickly as possible.
Heavily inspired by Red-Gate's Puppet Bootstrap project.

**Disclaimer**: I have no idea what I'm doing.

## Puppet Master 
The purpose of this script is to aid in the setting up of a new Puppet server from scratch, this is extremely useful when testing out a major Puppet release as you are able to spin up and test with relative ease.
It does this by installing Puppet and r10k then letting them take over to do the heavy lifting.

This makes certain assumptions about your environment:
* Version control through `r10k` (https://github.com/puppetlabs/r10k)
* Role based classification as opposed to node classification (https://puppet.com/docs/pe/2018.1/the_roles_and_profiles_method.html)
* **Ubuntu** or **CentOS** as host OS (though I would like to support Debian in the future)
* Default install directories
* A `hiera-bootstrap.yaml` file in your envrionment (see `example-bootstrap-hiera.yaml` in this repo for how I am using it)
* Your machine is not going to be named as `Puppetserver` or `Puppetmaster` (these should be set as CNAME's rather than the hostname of the machine to allow for easy upgrade paths)

This script will:
* Install the relevant versionn of Puppet for your OS
* Setup a Git SSH key for you to add to your Puppet repo(s)
* Setup r10k
* Run a `puppet apply` using a given puppet Module name

It's not perfect but if I can do it then you can too 😇

There's a few command line arguments that you can pass in, if you don't specify a ***reuired*** paramater you will be prompted to do so later on:
* `-h|--hostname` **(*required*)** the hostname of the machine you are building, should be FQDN but the script will attempt to fix that if not.
* `-E|--puppetenv` **(*required*)** the Puppet environment you'll use (aka Git branch name)
* `-d|--domain` **(*required*)** the domain that your Puppet server should be part of (eg foo.com)
* `-g|--gitrepo` **(*optional*)** the ssh address of the Github repo to use for your version control
* `-P|--puppetversion` **(*optional*)** the major release of puppet to use (defaults to Puppet6)

There's some config options that are set within the script themselves as they are unlikely to change much between runs.
* `DEFAULT_DOMAIN` this is the domain for which to append any missing FQDN information. (eg `.foo.com`)
* `GITREPO` the ssh address of the Git repository you are using to store your Puppet environments
* `PUPPET_VER` the major version of Puppet to use (eg `Puppet6`)
* `PP_ENVIRONMENT`, `PP_SERVICE` & `PP_ROLE` used in the role based classification of your Puppet master, you may want to change these to match your environment.

## Testing
If you want to do some testing then you'll want to install Vagrant and Virtualbox, this can be done with relative ease via Chocolatey:  
`choco install vagrant, virtualbox`  
This works well for testing changes to the scripts and some basic Puppet stuff, for anything more involved you'll really want to setup a virtual test envrionment.

Currently there are 2 vagrant boxes in this repo:
`puppetlinux` and `puppetmaster`

If you're using Puppetboard as part of your build you'll need to head to http://127.0.0.1:8080/branch_name/ to avoid 404 errors