#!/bin/bash -e

CURWD=`pwd`
echo $CURWD
# spring ------------------------->>>
PKG_SRC=usb
if [ $PKG_SRC == "usb" ]; then
  mkdir -p /media/x7_usb
  sudo mount /dev/sdb4 /media/x7_usb
fi
# --------------------------------<<<

PACKAGES="apache2 apache2-mpm-worker apache2-utils apache2.2-bin apache2.2-common blt bridge-utils cloud-utils cpu-checker curl dnsmasq-utils   ebtables erlang-asn1 erlang-base erlang-corba erlang-crypto erlang-dev erlang-docbuilder erlang-edoc erlang-erl-docgen erlang-eunit   erlang-ic erlang-inets erlang-inviso erlang-mnesia erlang-nox erlang-odbc erlang-os-mon erlang-parsetools erlang-percept erlang-public-key   erlang-runtime-tools erlang-snmp erlang-ssh erlang-ssl erlang-syntax-tools erlang-tools erlang-webtool erlang-xmerl euca2ools gawk   git-core javascript-common kpartx kvm libaio1 libapache2-mod-wsgi libapparmor1 libapr1 libaprutil1 libaprutil1-dbd-sqlite3   libaprutil1-ldap libblas3gf libconfig-general-perl libcurl3 libdbd-mysql-perl libdbi-perl libexpat1-dev libgfortran3 libhtml-template-perl   libibverbs1 libjs-jquery-metadata libjs-jquery-tablesorter libjs-sphinxdoc libjs-underscore liblapack3gf libldap2-dev libnet-daemon-perl   libplrpc-perl libpython2.6 librdmacm1 libreadline5 libruby1.8 libsasl2-dev libsctp1 libsigsegv2 libssl-dev libssl-doc libtidy-0.99-0   libvirt-bin libvirt0 libxenstore3.0 libxml2-utils libxss1 libyaml-0-2 lksctp-tools locate lvm2 memcached msr-tools mysql-client-5.1   mysql-client-core-5.1 mysql-server mysql-server-5.1 mysql-server-core-5.1 odbcinst odbcinst1debian2 open-iscsi open-iscsi-utils   openssh-server pep8 pylint python-amqplib python-anyjson python-argparse python-bcrypt python-boto python-carrot python-cheetah   python-cherrypy3 python-cloudfiles python-configobj python-coverage python-decorator python-dev python-dingus python-django   python-django-mailer python-django-nose python-django-registration python-docutils python-eventlet python-feedparser python-formencode   python-gflags python-greenlet python-iso8601 python-jinja2 python-kombu python-libvirt python-lockfile python-logilab-astng   python-logilab-common python-lxml python-m2crypto python-markupsafe python-migrate python-mox python-mysqldb python-netaddr   python-netifaces python-nose python-numpy python-openid python-paramiko python-paste python-pastedeploy python-pastescript python-pip   python-pygments python-pysqlite2 python-roman python-routes python-scgi python-setuptools python-sphinx python-sqlalchemy   python-sqlalchemy-ext python-stompy python-suds python-tempita python-tk python-unittest2 python-utidylib python-virtualenv python-webob   python-xattr python-yaml python2.6 python2.6-minimal python2.7-dev qemu-common qemu-kvm rabbitmq-server screen seabios sg3-utils socat   sqlite3 ssh-import-id tcl8.5 tgt tk8.5 unixodbc vgabios vim-nox vim-runtime vlan watershed wwwconfig-common xfsprogs zlib1g-dev build-essential dpkg-dev fakeroot g++ g++-4.6 libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libdpkg-perl libstdc++6-4.6-dev libtimedate-perl libldap-2.4-2 libssl1.0.0 python-libxml2 python-prettytable dnsmasq-base git-core iputils-arping   libasound2 libasyncns0 libdevmapper-event1.02.1   libflac8   libfontenc1   libgl1-mesa-dri   libgl1-mesa-glx libglapi-mesa   libibverbs1   libice6 libjpeg62 libjson0 liblcms1   libldap2-dev   libllvm2.9   liblua5.1-0   libmysqlclient16   libogg0 libpaper-utils libpaper1 libperl5.12   libpulse0 libsdl1.2debian   libsdl1.2debian-alsa   libsgutils2-2 libsm6   libsndfile1   libsysfs2 libtidy-0.99-0   libutempter0   libvorbis0a   libvorbisenc2   libxaw7   libxcb-shape0   libxcomposite1 libxdamage1   libxfixes3 libxft2 libxi6   libxinerama1   libxmu6   libxpm4   libxslt1.1   libxt6   libxtst6   libxv1   libxxf86dga1 libxxf86vm1 msr-tools   mysql-common python-dateutil   python-django   python-egenix-mxdatetime python-egenix-mxtools   python-imaging python-libxml2   python-logilab-common   python-lxml python-support unzip x11-common   x11-utils   xbitmaps   xterm libltdl7 libcap2 libavahi-client3 libavahi-common3 libavahi-common-data git git-man liberror-perl binutils build-essential cpp cpp-4.6 dpkg-dev fakeroot g++ g++-4.6 gcc gcc-4.6 libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libc-dev-bin libc6-dev libdpkg-perl libgomp1 libmpc2 libmpfr4 libquadmath0 libstdc++6-4.6-dev linux-libc-dev make manpages-dev libc-bin libc6 python-pkg-resources"

function aptcache () {
  mkdir -p $CURWD/cache/apt/
  sudo apt-get update
  sudo apt-get install -y --force-yes dpkg-dev
  cd $CURWD/cache/apt/
  apt-get download $PACKAGES
  sudo dpkg-scanpackages . /dev/null | gzip -c9 > Packages.gz
}
function imgcache () {
  mkdir -p $CURWD/img/
  if [ $PKG_SRC == "usb" ]; then
# spring ----------------------------->>>
    cp /media/x7_usb/cirros-0.3.0-x86_64-uec.tar.gz $CURWD/img/cirros-0.3.0-x86_64-uec.tar.gz
# ------------------------------------<<<
  else
    wget http://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-uec.tar.gz -O $CURWD/img/cirros-0.3.0-x86_64-uec.tar.gz
    #wget http://cloud-images.ubuntu.com/releases/oneiric/release/ubuntu-11.10-server-cloudimg-amd64.tar.gz -O $CURWD/img/ubuntu-11.10-server-cloudimg-amd64.tar.gz
  fi
  cp -f $CURWD/img/cirros-0.3.0-x86_64-uec.tar.gz $CURWD/img/ubuntu-11.10-server-cloudimg-amd64.tar.gz
}

function openstackcache () {
  git clone git://github.com/zz7a5pe4/x7_dep.git $CURWD/cache/stack
}

function pipcache () {
  mkdir -p $CURWD/cache/pip
  if [ $PKG_SRC == "usb" ]; then
# spring ------------------------------->>>
    tar xzf /media/x7_usb/pika-0.9.5.tar.gz -C $CURWD/cache/pip/
    tar xzf /media/x7_usb/passlib-1.5.3.tar.gz -C $CURWD/cache/pip/
    tar xzf /mdedia/x7_usb/django-nose-selenium-0.7.3.tar.gz -C $CURWD/cache/pip/
# --------------------------------------<<<
  else
    wget https://github.com/downloads/jkerng/x7/pika-0.9.5.tar.gz -O $CURWD/cache/pip/pika-0.9.5.tar.gz
    tar xzf $CURWD/cache/pip/pika-0.9.5.tar.gz -C $CURWD/cache/pip/
    rm -f $CURWD/cache/pip/pika-0.9.5.tar.gz
    wget https://github.com/downloads/jkerng/x7/passlib-1.5.3.tar.gz -O $CURWD/cache/pip/passlib-1.5.3.tar.gz
    tar xzf $CURWD/cache/pip/passlib-1.5.3.tar.gz -C $CURWD/cache/pip/
    rm -f $CURWD/cache/pip/passlib-1.5.3.tar.gz
    wget https://github.com/downloads/jkerng/x7/django-nose-selenium-0.7.3.tar.gz -O $CURWD/cache/pip/django-nose-selenium-0.7.3.tar.gz
    tar xzf $CURWD/cache/pip/django-nose-selenium-0.7.3.tar.gz -C $CURWD/cache/pip/
    rm -f $CURWD/cache/pip/django-nose-selenium-0.7.3.tar.gz
  fi
  chmod -R +r $CURWD/cache/pip || true
}

if [ $# == 0 ]; then
  echo "you must specify another paramter: cache or tar"
  exit -1
fi

update () {
  $CURWD/notify_status.py "$1" "$2"
  echo $1 $2
}

if [ $1 == "cache" ]; then
  aptcache
  update prog 50
  imgcache
  update prog 60
  openstackcache && true
  update prog 70
  pipcache
  update prog 80
fi

if [ $1 == "client" ]; then
  openstackcache || true
  pipcache  || true
fi

if [ $1 == "tar" ]; then
  echo "haha"
fi

