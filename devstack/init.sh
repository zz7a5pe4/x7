#!/bin/bash


SERVERADDR=192.168.1.2


if [ $# == 0 ]; then
  echo "missing argument"
  exit -1
fi 

source ./addrc


if [ $1 == "srv" ]; then
  cp localrc_server localrc
  sed -i "s|%HOSTADDR%|$HOSTADDR|g" localrc
elif [ $1 == "cln" ]; then
  cp localrc_compute localrc
  sed -i "s|%HOSTADDR%|$HOSTADDR|g" localrc
  sed -i "s|%SERVERADDR%|$SERVERADDR|g" localrc
else
  echo "wrong"
  exit -1
fi

chk_root () {

  if [ ! $( id -u ) -eq 0 ]; then
    echo "Please enter root's password."
    exec sudo -E su -m -c "${0} ${CMDLN_ARGS}" # Call this prog as root
    exit ${?}  # sice we're 'execing' above, we wont reach this exit
               # unless something goes wrong.
  fi

}

if [ -z "$MYID" ]; then
    export MYID=`whoami`
fi 

chk_root 

CURWD=`pwd`
CURWD=`dirname $CURWD`


grep "^$MYID ALL=(ALL) NOPASSWD: ALL$" /etc/sudoers > /dev/null
if [ "$?" -ne "0" ];
  then
    chmod +w /etc/sudoers
    echo "$MYID ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    chmod -w /etc/sudoers
  else
    echo "already in sudoer"
fi

cp -f ./stackrc_template ./stackrc
sed -e "s|%BASESRC%|$CURWD|g" -i ./stackrc
chown $MYID ./stackrc

cp -f ./functions_template ./functions
sed -e "s|%PIPLOCALCACHE%|$CURWD/cache/pip|g" -i ./functions
chown $MYID ./functions

if [ -f $CURWD/cache/apt/Packages.gz ]; then
  grep "^deb file://$CURWD/cache/apt/ /$" /etc/apt/sources.list > /dev/null
  #if [ "$?" -ne "0" ];
  #  then
  #    echo "deb file://$CURWD/cache/apt/ /" >> /etc/apt/sources.list
  #  else
  #    echo "already in source.list"
  #fi
  if [ -f /etc/apt/sources.list.backup ]; then
    echo "sources.list already backup"
  else
    sudo mv /etc/apt/sources.list /etc/apt/sources.list.backup
  fi
  echo "deb file://$CURWD/cache/apt/ /" > /etc/apt/sources.list
fi
apt-get update 
#apt-get update > /dev/null

echo "Done"
touch ./INITDONE
exit 0

