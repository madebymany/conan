#!/bin/bash
# Bootstrap chef on Ubuntu 10.04

function inform {
  status=$1
  echo
  echo -e "\e[33m• ${1}\e[0m"
  echo
}

function happy_ending {
  echo
  echo -e "\e[32m✓ ${1}\e[0m"
  exit 0
}

function croak {
  echo
  echo -e "\e[31m✗ $status failed. Aborting.\e[0m"
  exit 1
}

inform "Updating package index"
apt-get update || croak

command -v chef-solo >/dev/null && \
happy_ending "Chef is already bootstrapped. Nothing more to do."

inform "Setting up build environment"
apt-get install -y build-essential || croak

inform "Installing Ruby Enterprise Edition"
case `uname -m` in
  x86_64)
    REE="http://rubyforge.org/frs/download.php/71098/ruby-enterprise_1.8.7-2010.02_amd64_ubuntu10.04.deb"
    ;;
  *)
    REE="http://rubyforge.org/frs/download.php/71100/ruby-enterprise_1.8.7-2010.02_i386_ubuntu10.04.deb"
    ;;
esac
echo "Fetching ${REE}"
curl -s -L -o ree.deb "${REE}" || croak
dpkg -i ree.deb || croak
rm ree.deb

inform "Installing Chef"
gem install -v 0.5.8  ohai --no-rdoc --no-ri || croak
gem install -v 0.9.12 chef --no-rdoc --no-ri || croak

mkdir -p /etc/chef

happy_ending "Chef has been bootstrapped!"
