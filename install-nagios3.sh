#!/bin/bash
# Script for installing nagios-core, nagios-plugins 
# 
# 
# 
# 
# Tested Ubuntu 12.04

# Environment varibles
DOWNLOAD_DIR="/home/${USER}/downloads"
NAGIOS_CORE_NAME="nagios-3.4.1"
NAGIOS_CORE_FILE="${NAGIOS_CORE_NAME}.tar.gz"
NAGIOS_PLUGIN_NAME="nagios-plugins-1.4.16"
NAGIOS_PLUGIN_FILE="${NAGIOS_PLUGIN_NAME}.tar.gz"
URL="http://prdownloads.sourceforge.net/sourceforge"


# Define nagios home directory
read -p "Path of Nagios (/usr/local/nagios) : " nagios_home
nagios_home=${nagios_home:-"/usr/local/nagios"}

last_char=$(echo $nagios_home | tail -c 2)
if [ "$last_char" = "/" ]; then
        nagios_home="${nagios_home%/}"
fi


# Define the user who owns nagios & executes nagios
read -p "Enter Nagios user or current user will be set: " nagios_user
nagios_user=${nagios_user:-"$USER"}


# Define nagios web admin UI
read -p "Enter Nagios web admin ID or 'nagiosadmin' will be set: " nagiosweb_admin_id
nagiosweb_admin_id=${nagiosweb_admin_id:-"nagiosadmin"}


# Define nagios web admin password
#read -s "Enter Nagios web admin password: " nagiosweb_admin_pwd
unset nagiosweb_admin_pwd
prompt="Enter Password for nagios web admin:"
while IFS= read -p "$prompt" -r -s -n 1 char
do
     if [[ $char == $'\0' ]]
     then
         break
     fi
     prompt='*'
     nagiosweb_admin_pwd+="$char"
done

echo ''
echo '########  Installation Summary ########'
echo "Nagios HOME: $nagios_home"
echo "Nagios User: $nagios_user"
echo "Nagios Web admin: $nagiosweb_admin_id"
echo "Download Directory: $DOWNLOAD_DIR"
echo '####################################'
echo ''


# Install pre-requisites
sudo sudo apt-get install build-essential php5 php5-gd make libsnmp-base libsnmp-dev apache2 libgd2-xpm-dev


# Create directory for Nagios && change its ownership
if [-d "${nagios_home}" ]; then
  echo "Directory ${nagios_home} is already existed"
else  
  sudo mkdir -p ${nagios_home}
  sudo chown -R ${nagios_user}:${nagios_user} ${nagios_home} 
fi


# Check if download_dir is existed
if [ -d "${DOWNLOAD_DIR}" ]; then
  echo "Directory ${DOWNLOAD_DIR} is already existed"
else
  mkdir ${DOWNLOAD_DIR}
fi

# Download the source of Nagios-core
cd ${DOWNLOAD_DIR}
wget --directory-prefix=${DOWNLOAD_DIR} ${URL}/nagios/${NAGIOS_CORE_FILE}
tar -xzvf ./${NAGIOS_CORE_FILE}
cd ./nagios


# Add the Nagios User
test="$(grep ^${nagios_user}: /etc/passwd)"
if [ -n "${test}" ]; then
   echo "User ${nagios_user} is already on the system"
else
   echo "Adding ${nagios_user} to system"
   sudo useradd nagios
fi

#read -p "Do you want to continue this? (y/n) " RESP
#if [ "$RESP" = "n" ]; then
#  echo "Teminate the script."
#  exit 1
#fi

# Configuring
./configure --with-nagios-user=${nagios_user} --with-command-user=${nagios_user} --prefix=${nagios_home}

#######################
# Compiling & Installing
#######################
# Compiling
make all

# install main program and web UI
sudo make install

# auto start script
sudo make install-init  

# config files 
sudo make install-config

# configuration with apache
sudo make install-webconf

# command mode
sudo make install-commandmode

# Securing web page with nagios user
sudo htpasswd -cb "${nagios_home}/etc/htpasswd.users" ${nagiosweb_admin_id} ${nagiosweb_admin_pwd} 
sudo chown ${nagios_user}:${nagios_user} ${nagios_home}/etc/htpasswd.users

# Add default apache2 user to nagios group for being able to excute 'nagios.cmd' via web 
sudo usermod -G ${nagios_user} -a www-data


########################
# Nagios plug-ins
########################
sudo apt-get install libssl-dev

cd ${DOWNLOAD_DIR}
wget --directory-prefix=${DOWNLOAD_DIR} ${URL}/nagiosplug/${NAGIOS_PLUGIN_FILE}
tar -xzvf ${NAGIOS_PLUGIN_FILE}
cd ${NAGIOS_PLUGIN_NAME}
./configure --with-nagios-user=${nagios_user} --with-nagios-group=${nagios_user} --prefix=${nagios_home}
sudo make
sudo make install
