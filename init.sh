#!/bin/bash

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

MYID=q
PWD=`pwd`
PWD=`dirname $PWD`


chmod +w /etc/sudoers
echo "$MYID ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -w /etc/sudoers

cp -f ./stackrc_template ./stackrc
sed -e "s|%BASESRC%|$PWD|g" -i ./stackrc

cp -f ./functions_template ./functions
sed -e "s|%PIPLOCALCACHE%|$PWD/cache/pip|g" -i ./functions

#sed -e "s|%BASESRC%|$PWD|g" -i ./restart_stack.sh
apt-get update
cp -rf $PWD/cache/apt /var/cache/


echo "Done"
touch ./INITDONE



