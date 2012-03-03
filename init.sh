#!/bin/bash

MYID=q

PWD=`pwd`
PWD=`dirname $PWD`


chmod +w /etc/sudoers
#echo "$MYID ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -w /etc/sudoers

cp -f ./stackrc_template ./stackrc
sed -e "s|%BASESRC%|$PWD|g" -i ./stackrc
#sed -e "s|%BASESRC%|$PWD|g" -i ./restart_stack.sh
apt-get update
cp -rf $PWD/cache/apt /var/cache/


echo "Done"




