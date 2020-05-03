#!/bin/bash
### START OF CONF ###
## You probably want to change these ##
DEFAULT_DOMAIN=
PUPPETMASTER=
PUPPET_VER="puppet6"
## You _may_ want to change these
WAIT_FOR_CERT=30 # how long Puppet will wait between checking for the cert, if set to 0 then the script will be paused while you sign the cert.
PUPPETENV="production"
PUPPETAGENT_VER="latest"

## You probably _don't_ want to change these ##
TEMP_DIR="setup-tmp" # if you change this it's worth adding the new value to your .gitignore if you are using vagrant
delete_on_exit=true
PUPPETPORT="8140"
### END CONF ###

# Check we're root.
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo ${0##*/}" 1>&2
   exit 1
fi

throw() {
  printf '%s\n' "$1" >&2
  exit 1
}

### ARGUMENT PARSER ###
while :; do
    case $1 in
        -h|--hostname)
            if [ "$2" ]; then
                NEWHOSTNAME="$2"
                shift
            else
                throw 'ERROR: "-h|--hostname" requires a value'
            fi
        ;;
        -d|--domain)
            if [ "$2" ]; then
                DEFAULT_DOMAIN="$2"
                shift
            else
                throw 'ERROR: "-d|--domain" requires a value'
            fi
        ;;
        -m|--puppetmaster)
            if [ "$2" ]; then
                PUPPETMASTER="$2"
                shift
            else
                throw 'ERROR: "-m|--puppetmaster" requires a value'
            fi
        ;;
        -p|--puppetport)
            if [ "$2" ]; then
                PUPPETPORT="$2"
                shift
            else
                throw 'ERROR: "-p|--puppetport" requires a value'
            fi
        ;;
        -E|--puppetenv)
            if [ "$2" ]; then
                PUPPETENV="$2"
                shift
            else
                throw 'ERROR: "-E|--puppetenv" requires a value'
            fi
        ;;
        -e|--ppenv)
            if [ "$2" ]; then
                PP_ENVIRONMENT="$2"
                shift
            else
                throw 'ERROR: "-e|--ppenv" requires a value'
            fi
        ;;
        -s|--ppservice)
            if [ "$2" ]; then
                PP_SERVICE="$2"
                shift
            else
                throw 'ERROR: "-s|--ppservice" requires a value'
            fi
        ;;
        -r|--pprole)
            if [ "$2" ]; then
                PP_ROLE="$2"
                shift
            else
                throw 'ERROR: "-r|--pprole" requires a value'
            fi
        ;;
        -V|--puppetversion)
            if [ "$2" ]; then
                PUPPET_VER="$2"
                shift
            else
                throw `ERROR: "-V|--puppetversion" requires a value`
            fi
        ;;
        -A|--puppetagentversion)
            if [ "$2" ]; then
                PUPPETAGENT_VER="$2"
                shift
            else
                throw `ERROR: "-A|--puppetagentversion" requires a value`
            fi
        ;;
        -w|--wait)
            WAIT_FOR_CERT=0
        ;;
        *)
            if [ $1 ]; then
                throw "ERROR: unsupported parameter passed: '$1'"
            else
                break
            fi
    esac
    shift
done
### END ARGUMENT PARSER ###

### START CHECKS ###
# Check if Puppet is already installed
# this is just temporary - I'll find a better way
PUPPET_TEST=`dpkg --get-selections | grep puppet`
if [ "$PUPPET_TEST"  ]; then
    throw "It looks like Puppet is already installed on this machine."
fi

if [ -z "$DEFAULT_DOMAIN" ]; then
    read -p "Enter your domain name (eg foo.com): " DEFAULT_DOMAIN
fi

# Make sure we have a sensible hostname (could WHILE this to ensure we don't keep bombing out of the script)
if [ -z "$NEWHOSTNAME" ]; then
    read -p "Enter a hostname for this machine: " NEWHOSTNAME
fi
if  [[ "$NEWHOSTNAME" != *".$DEFAULT_DOMAIN"* ]]; then
    NEWHOSTNAME+=".${DEFAULT_DOMAIN}"
fi
# ensure we're not going to kill off an existing machine (Debian/Ubuntu use 127.0.1.1)
HOST_CHECK=$(getent ahostsv4 $NEWHOSTNAME | awk '{print $1}' | head -1)
if ! [ "$HOST_CHECK" = "" ]; then
    HOSTNAME_IP=$(hostname -I)
    IP_ARR=($HOSTNAME_IP)
    if ! [[ " ${IP_ARR[@]} " =~ " ${HOST_CHECK} " ]]; then
        throw "$NEWHOSTNAME already seems to belong to: $HOST_CHECK"
    fi
fi
if [ -z "$PUPPETENV" ]; then
    read -p "Please enter the Puppet environment (git branch) to use: " PUPPETENV
fi

# Ensure we've got a FQDN for our Puppet master
if [ -z "$PUPPETMASTER" ]; then
    read -p "Enter puppet master hostname: " PUPPETMASTER
fi
if [[ "$PUPPETMASTER" != *"."$DEFAULT_DOMAIN* ]]; then
   PUPPETMASTER+=".${DEFAULT_DOMAIN}"
fi

ping -q -c3 "$PUPPETMASTER" &> /dev/null
if [ $? != 0 ]; then
   throw "Can't contact $PUPPETMASTER, are you sure it's correct?"
fi

if [ -z "$PUPPETENV" ]; then
    read -p "Please enter the Puppet environment (git branch) to use: " PUPPETENV
fi

if [ -z "$PP_ENVIRONMENT$PP_SERVICE$PP_ROLE" ]; then
    read -p "Would you like to set additional csr attributes? (service/role/pp_envrionment) [y/N]:" SET_EXTRA_ATTRIBUTES
    if [ $SET_EXTRA_ATTRIBUTES ] && [ ${SET_EXTRA_ATTRIBUTES,,} == "y" ]; then
    	read -p "pp_environment (eg live/test): " PP_ENVIRONMENT
    	read -p "pp_service (eg webserver/buildserver): " PP_SERVICE
    	read -p "pp_role (eg cdn/teamcity): " PP_ROLE
    fi
fi

if [ -z "$PUPPET_VER" ]; then
    read -p "Please enter Puppet version to install (eg Puppet6): " PUPPET_VER
fi
### END OF CHECKS ###

echo "
All prerequisite checks have passed, this machine will be configured with:

Hostname: $NEWHOSTNAME
Puppet Version: $PUPPET_VER
Puppet Master: $PUPPETMASTER (PORT: $PUPPETPORT)
Puppet Environment: $PUPPETENV
Extended Certificate Attributes:
    Environment: $PP_ENVIRONMENT
    Service: $PP_SERVICE
    Role: $PP_ROLE
"
if [ $WAIT_FOR_CERT == 0 ]; then
    echo "You have opted to pause the provisioning while you sign the Puppet certificate on $PUPPETMASTER"
fi
read -p "If you're happy press 'enter' to continue, otherwise press 'ctrl + c' to abort..."

### Begin Provisioning ###

echo "Setting hostname to $NEWHOSTNAME"
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname

if [ -d "/vagrant" ];then
    cd "/vagrant" # assume we're running in a vagrant box and want to do some testing!
fi

if [ ! -d "$TEMP_DIR" ];then
    mkdir "$TEMP_DIR"
fi

dist=`awk -F= '/^NAME/{print $2}' /etc/os-release`

cd "$TEMP_DIR"
dist=`awk -F= '/^NAME/{print $2}' /etc/os-release`
# TODO: Debian support?
if [ "$dist" == "\"CentOS Linux\"" ]; then
    version=`awk -F= '/^VERSION_ID/{print $2}' /etc/os-release`
    URL="https://yum.puppetlabs.com/puppet6/${PUPPET_VER}-release-el-${version//\"}.noarch.rpm"
    echo "Fetching installer from $URL"
    wget "$URL" || exit 1
    rpm -Uvh ${PUPPET_VER}-release-el-${version//\"}.noarch.rpm || exit 1
    echo "Installing Puppet Agent"
    yum update || exit 1
    if [ "$PUPPETAGENT_VER" != 'latest' ]; then
        yum install puppet-agent "$PUPPETAGENT_VER" -y || exit 1
    else
        yum install puppet-agent -y || exit 1
    fi
elif [ "$dist" == "\"Ubuntu\"" ]; then
    RELEASE_NAME=`lsb_release -c -s`
    URL="https://apt.puppetlabs.com/${PUPPET_VER}-release-${RELEASE_NAME}.deb"
    echo "Fetching installer from $URL"
    wget "$URL" || exit 1
    dpkg -i ${PUPPET_VER}-release-${RELEASE_NAME}.deb || exit 1
    apt-get update || exit 1
    echo "installing Puppet Agent"
    if [ "$PUPPETAGENT_VER" != 'latest' ]; then
        apt-get install puppet-agent "$PUPPETAGENT_VER" || exit 1
    else
        apt-get install puppet-agent || exit 1
    fi
else
    throw "Currently only Ubuntu and CentOS are supported."
fi
if [ "$delete_on_exit" = true ]; then
    rm -r $TEMP_DIR
fi

# Add puppet to this session's PATH (hopefully the installer will sort it for future sessions)
export PATH=$PATH:/opt/puppetlabs/bin

# Set the Puppet config
echo "Setting Puppet config"
/opt/puppetlabs/bin/puppet config set server $PUPPETMASTER --section main || exit 1
/opt/puppetlabs/bin/puppet config set masterport $PUPPETPORT --section main || exit 1
/opt/puppetlabs/bin/puppet config set environment $PUPPETENV --section agent || exit 1
/opt/puppetlabs/bin/puppet config set certname $NEWHOSTNAME --section main || exit 1

# Set any extra CSR's
if [ ! -z "$PP_ENVIRONMENT$PP_SERVICE$PP_ROLE" ]; then
	echo "extension_requests:" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ENVIRONMENT ] && echo "    pp_environment: $PP_ENVIRONMENT" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_SERVICE ] && echo "    pp_service: $PP_SERVICE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ROLE ] && echo "    pp_role: $PP_ROLE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
fi

/opt/puppetlabs/bin/puppet agent -t --waitforcert $WAIT_FOR_CERT
# Enable puppet
/opt/puppetlabs/bin/puppet agent --enable

if [ $WAIT_FOR_CERT = 0 ]; then
    Read -p "Please sign this node on $PUPPETMASTER and press enter to continue..."
    puppet agent -t
fi

