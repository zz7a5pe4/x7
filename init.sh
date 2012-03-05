#!/bin/bash


chk_root () {

  if [ ! $( id -u ) -eq 0 ]; then
    echo "Please enter root's password."
    exec sudo su -c "${0} ${CMDLN_ARGS}" # Call this prog as root
    exit ${?}  # sice we're 'execing' above, we wont reach this exit
               # unless something goes wrong.
  fi

}

MYID=`whoami`

if [ -f ./INITDONE ]
  then
    echo "Please remove ./INITDONE first if you DO need to re-init"
    echo "FAILED"
    exit -1
fi

chk_root 

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

apt-get update 
#apt-get update > /dev/null

echo "Done"
touch ./INITDONE
exit 0

