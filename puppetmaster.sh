#!/bin/bash
### START OF CONF ###
## You probably want to change these ##
DEFAULT_DOMAIN="local"
GITREPO="git@github.com:shoddyguard/brownserve_deployment.git"
PUPPET_VER="puppet6"

## You _may_ want to change these ##
PP_ENVIRONMENT="test"
PP_SERVICE="puppetserver"
PP_ROLE="$PUPPET_VER""_master"

## You probably _don't_ want to change these ##
TEMP_DIR="setup-tmp" # if you change this it's worth adding the new value to your .gitignore if you are using vagrant
EYAML_PRIVATEKEY="/etc/puppetlabs/puppet/keys/private_key.pkcs7.pem"
EYAML_PUBLICKEY="/etc/puppetlabs/puppet/keys/public_key.pkcs7.pem"
R10K_YAML="/etc/puppetlabs/r10k/r10k.yaml" # temporary to get us up and running, Puppet will take over in due course
### END OF CONF ###

throw() {
  printf '%s\n' "$1" >&2
  exit 1
}

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo ${0##*/}" 1>&2
   exit 1
fi

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
        -g|--gitrepo)
            if [ "$2" ]; then
                GITREPO="$2"
                shift
            else
                throw 'ERROR: "-g|--gitrepo" requires a value'
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
        -E|--puppetenv)
            if [ "$2" ]; then
                PUPPETENV="$2"
                shift
            else
                throw 'ERROR: "-E|--puppetenv" requires a value'
            fi
        ;;
        -P|--puppetversion)
            if ["$2"]; then
                PUPPET_VER="$2"
                shift
            else
                throw `ERROR: "-P|--puppetversion" requires a value`
            fi
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

### START TEX-MEX PRE-REQS CHECKS ###

# this is just temporary - I'll find a better way
PUPPET_TEST=`dpkg --get-selections | grep puppet`
if [ "$PUPPET_TEST"  ]; then
    throw "It looks like Puppet is already installed on this machine."
fi

if [ -z "$DEFAULT_DOMAIN" ]; then
    read -p "Enter your domain name (eg contoso.com): " DEFAULT_DOMAIN
fi

if [ -z "$GITREPO" ]; then
    read -p "Enter in the git repo where your environments live: " GITREPO
fi

# Make sure we have a sensible hostname (could WHILE this to ensure we don't keep bombing out of the script)
if [ -z "$NEWHOSTNAME" ]; then
    read -p "Enter a hostname for this machine: " NEWHOSTNAME
fi
if [[ "$NEWHOSTNAME" == *"puppetserver"* ]] || [[ "$NEWHOSTNAME" == *"puppetmaster"* ]]; then
    throw "Cannot use PUPPETSERVER as hostname, this should be set as a CNAME in DNS to allow for easy upgrade paths"
fi
if  [[ "$NEWHOSTNAME" != *".$DEFAULT_DOMAIN"* ]]; then
    NEWHOSTNAME+=".${DEFAULT_DOMAIN}"
fi
# ensure we're not going to kill off an existing Puppet server! (Debian/Ubuntu use 127.0.1.1)
HOST_CHECK=$(getent ahostsv4 $NEWHOSTNAME | awk '{print $1}' | head -1)
if ! [[ $HOST_CHECK =~ 127.0.[0-1].1 ]]; then
    throw "$NEWHOSTNAME already seems to belong to: $HOST_CHECK"
fi
if [ -z "$PUPPETENV" ]; then
    read -p "Please enter the Puppet environment (git branch) to use: " PUPPETENV
fi


# Create dirs for copying our stuff too. (-p means we recurse and don't care if directories already exist)
mkdir -p "/etc/puppetlabs/puppet/keys" || exit 1
mkdir -p "/etc/puppetlabs/r10k" || exit 1

if [ -d "/vagrant" ];then
    cd "/vagrant" # assume we're running in a vagrant box and want to do some testing!
fi

if [ ! -d "$TEMP_DIR" ];then
    mkdir "$TEMP_DIR"
fi

if [ -f "$TEMP_DIR/private_key.pkcs7.pem" ]; then
    echo "eyaml private key found"
    cp "$TEMP_DIR/private_key.pkcs7.pem" $EYAML_PRIVATEKEY || exit 1
fi

if [ -f "$TEMP_DIR/public_key.pkcs7.pem" ]; then
    echo "eyaml public key found"
    cp "$TEMP_DIR/public_key.pkcs7.pem" $EYAML_PUBLICKEY || exit 1
fi

if [ -f "$TEMP_DIR/r10k.yaml" ]; then
    echo "r10k yaml found"
    cp "$TEMP_DIR/r10k.yaml" $R10K_YAML || exit 1
fi

if [ ! -f  "$EYAML_PRIVATEKEY" ]; then
    echo "The eyaml private key does not exist in /etc/puppetlabs/puppet/keys/"
    echo "Please paste the private key below, press ctrl + d once you are finished to save."
    echo "Please paste the key:"
    EYAML_PRI=$(cat)
    if [ ! "$EYAML_PRI" ]; then
        throw "No key provided"
    fi
    echo "$EYAML_PRI" > "$EYAML_PRIVATEKEY" || exit 1
fi

if [ ! -f "$EYAML_PUBLICKEY" ]; then
    echo "The eyaml public key does not exist in /etc/puppetlabs/puppet/keys/"
    echo "Please paste the public key below, press ctrl + d once you are finished to save."
    echo "Please paste the key:"
    EYAML_PUB=$(cat)
    if [ ! "$EYAML_PUB" ]; then
        echo "No key provided"
        exit 1
    fi
    echo "$EYAML_PUB" > "$EYAML_PUBLICKEY" || exit 1
fi

if [ ! -f "$R10K_YAML" ]; then
    echo "The starter r10k yaml not exist in /etc/puppetlabs/r10k/"
    echo "Please paste the yaml below, press ctrl + d once you are finished to save."
    echo "Please paste the yaml:"
    YAML=$(cat)
    if [ ! "$YAML" ]; then
        echo "No yaml provided"
        exit 1
    fi
    echo "$YAML" > "$R10K_YAML" || exit 1
fi

if [ ! -d /root/.ssh ]; then
    mkdir /root/.ssh || exit 1
    chmod 700 /root/.ssh || exit 1
fi
### END TEX-MEX PRE-REQS CHECKS ###

### Start doing the things ###
echo "
All prerequisite checks have passed, this Puppet server will be configured with:

Hostname: $NEWHOSTNAME
Puppet Version: $PUPPET_VER
Source Control: $GITREPO
Starting Environment: $PUPPETENV
Extended Certificate Attributes:
    Environment: $PP_ENVIRONMENT
    Service: $PP_SERVICE
    Role: $PP_ROLE
"
read -p "If you're happy press 'enter' to continue, otherwise press 'ctrl + c' to abort..."

echo "Setting hostname to $NEWHOSTNAME"
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname

echo "Adding Github to known hosts list"
KEYSCAN=`ssh-keyscan github.com 2> /dev/null`|| exit 1
echo "$KEYSCAN" >> /root/.ssh/known_hosts

echo "Generating new SSH key pair."
# Silently generate our key pair
if [ ! -f /root/.ssh/id_rsa.pub ] 
then
    cat /dev/zero | ssh-keygen -b 2048 -t rsa -q -C "$NEWHOSTNAME" -N "" > /dev/null
fi

echo "Please copy the following key into the deploy keys on your GitHub repo"

cat /root/.ssh/id_rsa.pub

read -p "Press enter to continue..."
# We don't want to clone everything as that would be dumb so let's just check we can at least clone with a bare repo.
echo "Testing key pair works on $GITREPO"
git clone --bare "$GITREPO" "$TEMP_DIR/gittest" || throw "Failed to clone $GITREPO. Are you sure you copied the key?"

rm -r "$TEMP_DIR/gittest" # clean up

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
    yum install puppet-agent -y || exit 1
elif [ "$dist" == "\"Ubuntu\"" ]; then
    RELEASE_NAME=`lsb_release -c -s`
    URL="https://apt.puppetlabs.com/${PUPPET_VER}-release-${RELEASE_NAME}.deb"
    echo "Fetching installer from $URL"
    wget "$URL" || exit 1
    dpkg -i ${PUPPET_VER}-release-${RELEASE_NAME}.deb || exit 1
    apt-get update || exit 1
    echo "installing Puppet Agent"
    apt-get install puppet-agent || exit 1
else
    throw "Not Ubuntu or CentOS. Aborting."
fi

# Add puppet to this session's PATH (hopefully the installer will sort it for future sessions)
export PATH=$PATH:/opt/puppetlabs/bin

# Set the environment

/opt/puppetlabs/bin/puppet config --section agent set environment $PUPPETENV

echo "extension_requests:" >> /etc/puppetlabs/puppet/csr_attributes.yaml
[ $PP_ENVIRONMENT ] && echo "    pp_environment: $PP_ENVIRONMENT" >> /etc/puppetlabs/puppet/csr_attributes.yaml
[ $PP_SERVICE ] && echo "    pp_service: $PP_SERVICE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
[ $PP_ROLE ] && echo "    pp_role: $PP_ROLE" >> /etc/puppetlabs/puppet/csr_attributes.yaml

# Make sure the contents of /root/.ssh are owned correctly

chown root:root /root/.ssh/* || exit 1
chmod 0600 /root/.ssh/* || exit 1

echo "Installing Ruby and Git"
apt install ruby git -y || exit 1

echo "Installing r10k"
gem install r10k || exit 1

# We update all environments here as we may have nodes on different envs that we want to talk to our new server...
echo "Running r10k. This WILL take a while..."
/usr/local/bin/r10k deploy environment --puppetfile || throw "r10k failed to deploy, exit code: $?"

echo "Running puppet apply"
cd "/etc/puppetlabs/code/environments/$PUPPETENV" || exit 1
/opt/puppetlabs/bin/puppet apply --hiera_config="/etc/puppetlabs/code/environments/$PUPPETENV/hiera.bootstrap.yaml" --modulepath="./modules:./ext-modules" -e 'include bs_puppetserver' || exit 1


echo "
Initial setup done, Puppet should now take over and do the rest.
Don't forget to:
    * Create a DHCP reservation or static IP for this machine
    * Merge your branch and change the Puppet environment back to 'production'
    * Ensure eyaml keys are working correctly
"