# Puppet Provisioning
A collection of handy scripts to help you get up and running with Puppet as quickly as possible.
Heavily inspired by Red-Gate's Puppet Bootstrap project.

These scripts are intended for use in hiera based classification environments.

**Disclaimer**: I have no idea what I'm doing.

## Puppet Linux
This script will help you get Puppet installed and talking to a Puppet master.

Currently only Ubuntu is supported and the script has been validated on 18.04LTS

Command line arguments:
* `-h|--hostname` **(*required*)** the hostname of the machine you are building, should be the FQDN (eg webserver.foo.com) but the script will attempt to fix that if not
* `-d|--domain` **(*required*)** the domain that your machine should be part of (eg foo.com), this is needed to ensure hiera lookups work as intended
* `-E|--puppetenv` **(*optional*)** the environment/git branch to use (defaults to production)
* `-m|--puppetmaster` **(*required*)** the name of the Puppet master you are connecting to, this should be the FQDN (eg puppetmaster.foo.com)
* `-p|--puppetport` **(*optional*)** the port to use on the Puppet server (defaults to 8140)
* `-P|--puppetversion` **(*optional*)** the major release of puppet to use (defaults to Puppet6)
* `-w|--wait` **(*optional*)** if set will pause the script to wait for you to sign the node on the Puppet Master

In addtion to these, you can optinally set extended CSR attributes with the following:
* `-e|--ppenv` Sets the pp environment (eg live/test)
* `-s|--ppservice` Sets the pp service (eg webserver)
* `-r|--pprole` Sets the pp role (eg ngixnx_box or iis_box)

## Puppet Windows
This script will get a Windows machine talking to your Puppet master.

Script has been validated on server 2019 but it *should* work on Server 2012 onwards.

Parameters:
* `-PuppetMaster` **(*required*)** the name of the Puppet master you are connecting to, this should be the FQDN (eg puppetmaster.foo.com)
* `-DomainName` **(*required*)** the domain that your machine should be part of (eg foo.com), this is needed to ensure hiera lookups work as intended
* `-PuppetMajorVersion` **(*optional*)** the major release of puppet to use (defaults to Puppet6)
* `-PuppetAgentVersion` **(*optional*)** the version of puppet-agent to use (defaults to latest)
* `-MasterPort` **(*optional*)** the port to use on the Puppet server (defaults to 8140)
* `-PuppetEnvironment` **(*optional*)** the environment/git branch to use (defaults to production)
* `-CertificateExtensions` **(*optional*)** a hash of certificate extensions
* `-StartupMode` **(*optional*)** the `puppet-agent` service startup mode (defaults to automatic)
* `-WaitForCertificate` **(*optional*)** how long (in seconds) to wait between certificate checks (defaults to 30)

**example hash**


## Puppet Master 
The purpose of this script is to aid in the setting up of a new Puppet server from scratch, this is extremely useful when testing out a major Puppet release as you are able to spin up and test with relative ease.
It does this by installing Puppet and r10k then letting them take over to do the heavy lifting.

This makes certain assumptions about your environment:
* Version control through `r10k` (https://github.com/puppetlabs/r10k)
* **Ubuntu** as host OS (CentOS support flakey)
* Default install directories
* A `hiera-bootstrap.yaml` file in your envrionment (see `example-bootstrap-hiera.yaml` in this repo for how I am using it)
* Your machine is not going to be named as `Puppetserver` or `Puppetmaster` (these should be set as CNAME's rather than the hostname of the machine to allow for easy upgrade paths)

This script will:
* Install the relevant versionn of Puppet for your OS
* Setup a Git SSH key for you to add to your Puppet repo(s)
* Setup r10k
* Run a `puppet apply` using a given puppet Module name

It's not perfect, but it does the job.

There's a few command line arguments that you can pass in, if you don't specify a ***required*** paramater you will be prompted to do so later on:
* `-h|--hostname` **(*required*)** the hostname of the machine you are building, should be FQDN but the script will attempt to fix that if not.
* `-E|--puppetenv` **(*required*)** the Puppet environment you'll use (aka Git branch name)
* `-d|--domain` **(*required*)** the domain that your Puppet server should be part of (eg foo.com)
* `-g|--gitrepo` **(*required*)** the ssh address of the Github repo to use for your r10k version control
* `-C|--puppetserverclass` **(*required*)** the name of the class that your Puppet Master should use from your environment
* `-P|--puppetversion` **(*optional*)** the major release of puppet to use (defaults to Puppet6)

There's some config options that are set within the script themselves as they are unlikely to change much between runs.
* `DEFAULT_DOMAIN` this is the domain for which to append any missing FQDN information. (eg `.foo.com`)
* `GITREPO` the ssh address of the Git repository you are using to store your Puppet environments
* `PUPPET_VER` the major version of Puppet to use (eg `Puppet6`)
* `PP_ENVIRONMENT`, `PP_SERVICE` & `PP_ROLE` used in the hiera based lookup of your Puppet master, you may want to change these to match your environment.

## Testing
There's a [vagrantfile](vagrantfile) in the root of this repo that will allow you to quickly spin up VM's for testing changes to the scripts.
To run these you'll need to install [Vagrant](https://www.vagrantup.com/intro/index.html) and [Virtualbox](https://www.virtualbox.org/), on Windows this can easily be done using [Chocolatey](https://chocolatey.org/):  
`choco install vagrant, virtualbox`  
This method works well for testing changes to the scripts and even running a simple Puppet Master/Agent test environment but for anything more long term I would recommend spinning up a test environment with a permanent test Puppet Master.

If you're setting up a Puppet Master/Agent environment with Vagrant you'll also want to make sure you've a decent amount of RAM, the Puppet Master needs 4GB and each agent needs 2GB.
The boxes all have static IPs in the `192.168.69.x` range, if this conflicts with your local environment then you can change these from within the `vagrantfile`.
The boxes are also using mDNS to be able to talk to each other, this is needed so the Master/Agent testing can work. 

### Bootstrapping a Puppet environment using Vagrant
This will guide you through bootstrapping a Puppet environment from scratch, if you already have an existing Puppet environment then you can skip step 1.

**Step 1 - Setting up your Puppet Environment (Repo)**  
Pop over to my [hier-example](https://github.com/shoddyguard/puppet_hiera_example) repo and follow the instructions to make a copy of the repo and get setup ready to begin.

**Step 2 - Clone this repo**  
`git clone https://github.com/shoddyguard/Puppet-Provisioning.git`

**Step 3 (Optional) - Copy your setup files**  
If you want you can copy over your `private_key.pkcs7.pem`, `public_key.pkcs7.pem` and `r10k.yaml` files to the `passthru` folder in the root of this repo, if you don't do this you will be prompted to enter them into the script.

**Step 4 - Start the Puppet Master Box**  
Run the following command:  
`vagrant up puppettest-master`  
Wait for Vagrant to do it's thing and then login to the box with:
`vagrant ssh puppettest-master`

**Step 5 - Run the `puppetmaster.sh` script**  
`sudo bash /vagrant/puppetmaster.sh` and follow the on-screen instructions, if you want to save time you can pass in many of the variables as parameters (see [Puppet Master](#puppet-master) above).

If you're using my template hiera repository then you will want to use the following:
* Hostname: puppettest-master.local
* Default domain: local
* pp environment: test
* pp role: puppet6_master
* pp service: puppetserver
* Puppet server class: example_puppetserver

If at any point you make a mistake and want to start over just press `ctrl` + `c` to exit the script and start over.  
If things get really bad you can `vagrant destroy puppettest-master` and start again.

**Step 5 - Test!**  
Providing the script completes without issue you should now have a brand new working Puppet environment, congrats.
At this point it would be good to test that your hiera-eyaml and `sudo puppet agent -t` is running succesfully.

**Step 6 (Optional) - Set up a second Puppet node**  
A good test that your new Puppet Master is working correctly is to setup another node and have it connect back to the Master.  
To do this, you'll want to `vagrant up` one of the other boxes in the repo - I'd suggest the `puppetagent-ubuntu` box as it's a bit more lightweight than the `puppetagent-windows` box.  
Once your new box is ready go ahead and ssh into it and run the relevant script: `/vagrant/puppet-linux.sh` or `c:\vagrant\puppet-windows.ps1` and have them point to `puppettest-master.local` as their Puppet Master, providing mDNS is working as intended this should be fine - however I've had odd instances where this isn't the case and I've had to manually edit the `hosts` file to point to the Puppet Master.

**Step 7 (Optional) - Fork this repo to hardcode your information**  
If you're going to be running these scripts a lot for bootstrapping Puppet then you may want to fork this repo and hardcode your information into the scripts (eg Puppet Master, default domain etc) to reduce the amount of data you have to enter for each new node to the bare minimum.