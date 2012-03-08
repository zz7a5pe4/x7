#!/bin/bash

CURWD=`pwd`


function aptcache () {
  mkdir -p $CURWD/cache/apt/
  sudo apt-get install -y --force-yes dpkg-dev
  cd $CURWD/cache/apt/
  apt-get download pep8 pylint python-pip screen unzip wget psmisc git-core lsof  openssh-server vim-nox locate  python-virtualenv python-unittest2 iputils-ping wget curl tcpdump euca2ools  python-eventlet python-routes python-greenlet python-argparse python-sqlalchemy  python-pastedeploy python-xattr python-iso8601 apache2   libapache2-mod-wsgi   python-dateutil python-paste python-pastedeploy python-anyjson python-routes python-xattr python-sqlalchemy python-webob python-kombu pylint pep8 python-eventlet python-nose python-sphinx python-mox python-kombu python-coverage python-cherrypy3  python-django python-django-mailer python-django-nose python-django-registration python-cloudfiles python-migrate python-setuptools python-dev python-lxml python-pastescript python-pastedeploy python-paste sqlite3 python-pysqlite2 python-sqlalchemy python-webob python-greenlet python-routes libldap2-dev libsasl2-dev python-bcrypt python-dateutil lvm2 open-iscsi open-iscsi-utils python-numpy dnsmasq-base dnsmasq-utils  kpartx parted arping  iputils-arping  mysql-server  python-mysqldb python-xattr  python-lxml  kvm gawk iptables ebtables sqlite3 sudo kvm libvirt-bin vlan curl rabbitmq-server socat  python-mox python-paste python-migrate python-gflags python-greenlet python-libvirt python-libxml2 python-routes python-netaddr python-pastedeploy python-eventlet python-cheetah python-carrot python-tempita python-sqlalchemy python-suds python-lockfile python-m2crypto python-boto python-kombu python-feedparser python-iso8601 tgt lvm2 curl gcc memcached  python-configobj python-coverage python-dev python-eventlet python-greenlet python-netifaces python-nose python-pastedeploy python-setuptools python-simplejson python-webob python-xattr sqlite3 xfsprogs 
  sudo dpkg-scanpackages . /dev/null | gzip -c9 > Packages.gz
}

if [ $1 == "cache" ]; then
  aptcache
fi

