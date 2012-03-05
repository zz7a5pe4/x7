#!/bin/bash

MYID=x

if [ -f ./INITDONE ]
  then
    echo "Please remove ./INITDONE first if you DO need to re-init"
    echo "FAILED"
    exit -1
fi

if [ -z $1 ]
  then
    echo "you need a user id as parameter."
    echo "FAILED"
    exit -1
fi

if [[ $EUID -ne 0 ]]; then
    echo "you shoud run this script as root(sudo ./init.sh USERID	)"
    echo "FAILED"
    exit -1
fi

PWD=`pwd`
PWD=`dirname $PWD`


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
sed -e "s|%BASESRC%|$PWD|g" -i ./stackrc
chown $MYID ./stackrc

cp -f ./functions_template ./functions
sed -e "s|%PIPLOCALCACHE%|$PWD/cache/pip|g" -i ./functions
chown $MYID ./functions

grep "^deb file://$PWD/cache/apt/ /$" /etc/apt/sources.list > /dev/null
if [ "$?" -ne "0" ];
  then
    echo "deb file://$PWD/cache/apt/ /" >> /etc/apt/sources.list
  else
    echo "already in source.list"
fi

apt-get update > /dev/null
#cp -rf $PWD/cache/apt /var/cache/


echo "Done"
touch ./INITDONE
exit 0

