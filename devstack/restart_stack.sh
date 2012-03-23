#!/usr/bin/env bash

# **stack.sh** is an opinionated openstack developer installation.

# This script installs and configures *nova*, *glance*, *horizon* and *keystone*

# This script allows you to specify configuration options of what git
# repositories to use, enabled services, network configuration and various
# passwords.  If you are crafty you can run the script on multiple nodes using
# shared settings for common resources (mysql, rabbitmq) and build a multi-node
# developer install.

# To keep this script simple we assume you are running on an **Ubuntu 11.10
# Oneiric** machine.  It should work in a VM or physical server.  Additionally
# we put the list of *apt* and *pip* dependencies and other configuration files
# in this repo.  So start by grabbing this script and the dependencies.

# Learn more and get the most recent version at http://devstack.org

# Sanity Check
# ============

# Warn users who aren't on oneiric, but allow them to override check and attempt
# installation with ``FORCE=yes ./stack``
DISTRO=$(lsb_release -c -s)

if [[ ! ${DISTRO} =~ (oneiric) ]]; then
    echo "WARNING: this script has only been tested on oneiric"
    if [[ "$FORCE" != "yes" ]]; then
        echo "If you wish to run this script anyway run with FORCE=yes"
        exit 1
    fi
fi

# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
. $TOP_DIR/functions

# stack.sh keeps the list of **apt** and **pip** dependencies in external
# files, along with config templates and other useful files.  You can find these
# in the ``files`` directory (next to this script).  We will reference this
# directory using the ``FILES`` variable in this script.
FILES=$TOP_DIR/files
if [ ! -d $FILES ]; then
    echo "ERROR: missing devstack/files - did you grab more than just stack.sh?"
    exit 1
fi

source ./stackrc

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

# Check to see if we are already running a stack.sh
if type -p screen >/dev/null && screen -ls | egrep -q "[0-9].stack"; then
    killall screen; screen -wipe 
fi


# Set True to configure stack.sh to run cleanly without Internet access.
# stack.sh must have been previously run with Internet access to install
# prerequisites and initialize $DEST.
OFFLINE=`trueorfalse False $OFFLINE`

# Set the destination directories for openstack projects
NOVA_DIR=$DEST/nova
HORIZON_DIR=$DEST/horizon
GLANCE_DIR=$DEST/glance
KEYSTONE_DIR=$DEST/keystone
NOVACLIENT_DIR=$DEST/python-novaclient
KEYSTONECLIENT_DIR=$DEST/python-keystoneclient
NOVNC_DIR=$DEST/noVNC
SWIFT_DIR=$DEST/swift
QUANTUM_DIR=$DEST/quantum
QUANTUM_CLIENT_DIR=$DEST/python-quantumclient
MELANGE_DIR=$DEST/melange
MELANGECLIENT_DIR=$DEST/python-melangeclient

# Default Quantum Plugin
Q_PLUGIN=${Q_PLUGIN:-openvswitch}
# Default Quantum Port
Q_PORT=${Q_PORT:-9696}
# Default Quantum Host
Q_HOST=${Q_HOST:-localhost}

# Default Melange Port
M_PORT=${M_PORT:-9898}
# Default Melange Host
M_HOST=${M_HOST:-localhost}
# Melange MAC Address Range
M_MAC_RANGE=${M_MAC_RANGE:-404040/24}

# Specify which services to launch.  These generally correspond to screen tabs
ENABLED_SERVICES=${ENABLED_SERVICES:-g-api,g-reg,key,n-api,n-crt,n-obj,n-cpu,n-net,n-vol,n-sch,n-novnc,n-xvnc,n-cauth,horizon,mysql,rabbit}

# Name of the lvm volume group to use/create for iscsi volumes
VOLUME_GROUP=${VOLUME_GROUP:-nova-volumes}
VOLUME_NAME_PREFIX=${VOLUME_NAME_PREFIX:-volume-}
INSTANCE_NAME_PREFIX=${INSTANCE_NAME_PREFIX:-instance-}

# Nova hypervisor configuration.  We default to libvirt whth  **kvm** but will
# drop back to **qemu** if we are unable to load the kvm module.  Stack.sh can
# also install an **LXC** based system.
VIRT_DRIVER=${VIRT_DRIVER:-libvirt}
LIBVIRT_TYPE=${LIBVIRT_TYPE:-kvm}

# nova supports pluggable schedulers.  ``SimpleScheduler`` should work in most
# cases unless you are working on multi-zone mode.
SCHEDULER=${SCHEDULER:-nova.scheduler.simple.SimpleScheduler}

HOST_IP_IFACE=${HOST_IP_IFACE:-eth0}
# Use the eth0 IP unless an explicit is set by ``HOST_IP`` environment variable
if [ -z "$HOST_IP" -o "$HOST_IP" == "dhcp" ]; then
    HOST_IP=`LC_ALL=C /sbin/ifconfig ${HOST_IP_IFACE} | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
    if [ "$HOST_IP" = "" ]; then
        echo "Could not determine host ip address."
        echo "Either localrc specified dhcp on ${HOST_IP_IFACE} or defaulted to eth0"
        exit 1
    fi
fi

# Allow the use of an alternate hostname (such as localhost/127.0.0.1) for service endpoints.
SERVICE_HOST=${SERVICE_HOST:-$HOST_IP}

# Configure services to syslog instead of writing to individual log files
SYSLOG=`trueorfalse False $SYSLOG`
SYSLOG_HOST=${SYSLOG_HOST:-$HOST_IP}
SYSLOG_PORT=${SYSLOG_PORT:-516}

# Service startup timeout
SERVICE_TIMEOUT=${SERVICE_TIMEOUT:-60}

# Generic helper to configure passwords
function read_password {
    set +o xtrace
    var=$1; msg=$2
    pw=${!var}

    localrc=$TOP_DIR/localrc

    # If the password is not defined yet, proceed to prompt user for a password.
    if [ ! $pw ]; then
        # If there is no localrc file, create one
        if [ ! -e $localrc ]; then
            touch $localrc
        fi

        # Presumably if we got this far it can only be that our localrc is missing
        # the required password.  Prompt user for a password and write to localrc.
        echo ''
        echo '################################################################################'
        echo $msg
        echo '################################################################################'
        echo "This value will be written to your localrc file so you don't have to enter it "
        echo "again.  Use only alphanumeric characters."
        echo "If you leave this blank, a random default value will be used."
        pw=" "
        while true; do
            echo "Enter a password now:"
            read -e $var
            pw=${!var}
            [[ "$pw" = "`echo $pw | tr -cd [:alnum:]`" ]] && break
            echo "Invalid chars in password.  Try again:"
        done
        if [ ! $pw ]; then
            pw=`openssl rand -hex 10`
        fi
        eval "$var=$pw"
        echo "$var=$pw" >> $localrc
    fi
    set -o xtrace
}

# This function will check if the service(s) specified in argument is
# enabled by the user in ENABLED_SERVICES.
#
# If there is multiple services specified as argument it will act as a
# boolean OR or if any of the services specified on the command line
# return true.
#
# There is a special cases for some 'catch-all' services :
#      nova would catch if any service enabled start by n-
#    glance would catch if any service enabled start by g-
#   quantum would catch if any service enabled start by q-
function is_service_enabled() {
    services=$@
    for service in ${services}; do
        [[ ,${ENABLED_SERVICES}, =~ ,${service}, ]] && return 0
        [[ ${service} == "nova" && ${ENABLED_SERVICES} =~ "n-" ]] && return 0
        [[ ${service} == "glance" && ${ENABLED_SERVICES} =~ "g-" ]] && return 0
        [[ ${service} == "quantum" && ${ENABLED_SERVICES} =~ "q-" ]] && return 0
    done
    return 1
}

# Nova Network Configuration
# --------------------------

# FIXME: more documentation about why these are important flags.  Also
# we should make sure we use the same variable names as the flag names.

PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-br100}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.224/28}
NET_MAN=${NET_MAN:-FlatDHCPManager}
EC2_DMZ_HOST=${EC2_DMZ_HOST:-$SERVICE_HOST}
FLAT_NETWORK_BRIDGE=${FLAT_NETWORK_BRIDGE:-br100}
VLAN_INTERFACE=${VLAN_INTERFACE:-eth0}

# Test floating pool and range are used for testing.  They are defined
# here until the admin APIs can replace nova-manage
TEST_FLOATING_POOL=${TEST_FLOATING_POOL:-test}
TEST_FLOATING_RANGE=${TEST_FLOATING_RANGE:-192.168.253.0/29}

# Multi-host is a mode where each compute node runs its own network node.  This
# allows network operations and routing for a VM to occur on the server that is
# running the VM - removing a SPOF and bandwidth bottleneck.
MULTI_HOST=${MULTI_HOST:-False}

# If you are using FlatDHCP on multiple hosts, set the ``FLAT_INTERFACE``
# variable but make sure that the interface doesn't already have an
# ip or you risk breaking things.
#
# **DHCP Warning**:  If your flat interface device uses DHCP, there will be a
# hiccup while the network is moved from the flat interface to the flat network
# bridge.  This will happen when you launch your first instance.  Upon launch
# you will lose all connectivity to the node, and the vm launch will probably
# fail.
#
# If you are running on a single node and don't need to access the VMs from
# devices other than that node, you can set the flat interface to the same
# value as ``FLAT_NETWORK_BRIDGE``.  This will stop the network hiccup from
# occurring.
FLAT_INTERFACE=${FLAT_INTERFACE:-eth0}

## FIXME(ja): should/can we check that FLAT_INTERFACE is sane?

# Using Quantum networking:
#
# Make sure that quantum is enabled in ENABLED_SERVICES.  If it is the network
# manager will be set to the QuantumManager.  If you want to run Quantum on
# this host, make sure that q-svc is also in ENABLED_SERVICES.
#
# If you're planning to use the Quantum openvswitch plugin, set Q_PLUGIN to
# "openvswitch" and make sure the q-agt service is enabled in
# ENABLED_SERVICES.
#
# With Quantum networking the NET_MAN variable is ignored.

# Using Melange IPAM:
#
# Make sure that quantum and melange are enabled in ENABLED_SERVICES.
# If they are then the melange IPAM lib will be set in the QuantumManager.
# Adding m-svc to ENABLED_SERVICES will start the melange service on this
# host.


# MySQL & RabbitMQ
# ----------------

# We configure Nova, Horizon, Glance and Keystone to use MySQL as their
# database server.  While they share a single server, each has their own
# database and tables.

# By default this script will install and configure MySQL.  If you want to
# use an existing server, you can pass in the user/password/host parameters.
# You will need to send the same ``MYSQL_PASSWORD`` to every host if you are doing
# a multi-node devstack installation.
MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_USER=${MYSQL_USER:-root}
read_password MYSQL_PASSWORD "ENTER A PASSWORD TO USE FOR MYSQL."

# don't specify /db in this string, so we can use it for multiple services
BASE_SQL_CONN=${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST}

# Rabbit connection info
RABBIT_HOST=${RABBIT_HOST:-localhost}
read_password RABBIT_PASSWORD "ENTER A PASSWORD TO USE FOR RABBIT."

# Glance connection info.  Note the port must be specified.
GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$SERVICE_HOST:9292}

# SWIFT
# -----
# TODO: implement glance support
# TODO: add logging to different location.

# By default the location of swift drives and objects is located inside
# the swift source directory. SWIFT_DATA_LOCATION variable allow you to redefine
# this.
SWIFT_DATA_LOCATION=${SWIFT_DATA_LOCATION:-${SWIFT_DIR}/data}

# We are going to have the configuration files inside the source
# directory, change SWIFT_CONFIG_LOCATION if you want to adjust that.
SWIFT_CONFIG_LOCATION=${SWIFT_CONFIG_LOCATION:-${SWIFT_DIR}/config}

# devstack will create a loop-back disk formatted as XFS to store the
# swift data. By default the disk size is 1 gigabyte. The variable
# SWIFT_LOOPBACK_DISK_SIZE specified in bytes allow you to change
# that.
SWIFT_LOOPBACK_DISK_SIZE=${SWIFT_LOOPBACK_DISK_SIZE:-1000000}

# The ring uses a configurable number of bits from a path’s MD5 hash as
# a partition index that designates a device. The number of bits kept
# from the hash is known as the partition power, and 2 to the partition
# power indicates the partition count. Partitioning the full MD5 hash
# ring allows other parts of the cluster to work in batches of items at
# once which ends up either more efficient or at least less complex than
# working with each item separately or the entire cluster all at once.
# By default we define 9 for the partition count (which mean 512).
SWIFT_PARTITION_POWER_SIZE=${SWIFT_PARTITION_POWER_SIZE:-9}

# This variable allows you to configure how many replicas you want to be
# configured for your Swift cluster.  By default the three replicas would need a
# bit of IO and Memory on a VM you may want to lower that to 1 if you want to do
# only some quick testing.
SWIFT_REPLICAS=${SWIFT_REPLICAS:-3}

# We only ask for Swift Hash if we have enabled swift service.
if is_service_enabled swift; then
    # SWIFT_HASH is a random unique string for a swift cluster that
    # can never change.
    read_password SWIFT_HASH "ENTER A RANDOM SWIFT HASH."
fi

# Keystone
# --------

# Service Token - Openstack components need to have an admin token
# to validate user tokens.
read_password SERVICE_TOKEN "ENTER A SERVICE_TOKEN TO USE FOR THE SERVICE ADMIN TOKEN."
# Horizon currently truncates usernames and passwords at 20 characters
read_password ADMIN_PASSWORD "ENTER A PASSWORD TO USE FOR HORIZON AND KEYSTONE (20 CHARS OR LESS)."

# Set Keystone interface configuration
KEYSTONE_AUTH_HOST=${KEYSTONE_AUTH_HOST:-$SERVICE_HOST}
KEYSTONE_AUTH_PORT=${KEYSTONE_AUTH_PORT:-35357}
KEYSTONE_AUTH_PROTOCOL=${KEYSTONE_AUTH_PROTOCOL:-http}
KEYSTONE_SERVICE_HOST=${KEYSTONE_SERVICE_HOST:-$SERVICE_HOST}
KEYSTONE_SERVICE_PORT=${KEYSTONE_SERVICE_PORT:-5000}
KEYSTONE_SERVICE_PROTOCOL=${KEYSTONE_SERVICE_PROTOCOL:-http}

# Horizon
# -------

# Allow overriding the default Apache user and group, default both to
# current user.
APACHE_USER=${APACHE_USER:-$USER}
APACHE_GROUP=${APACHE_GROUP:-$APACHE_USER}

# Log files
# ---------

# Set up logging for stack.sh
# Set LOGFILE to turn on logging
# We append '.xxxxxxxx' to the given name to maintain history
# where xxxxxxxx is a representation of the date the file was created
if [[ -n "$LOGFILE" ]]; then
    # First clean up old log files.  Use the user-specified LOGFILE
    # as the template to search for, appending '.*' to match the date
    # we added on earlier runs.
    LOGDAYS=${LOGDAYS:-7}
    LOGDIR=$(dirname "$LOGFILE")
    LOGNAME=$(basename "$LOGFILE")
    find $LOGDIR -maxdepth 1 -name $LOGNAME.\* -mtime +$LOGDAYS -exec rm {} \;

    TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}
    LOGFILE=$LOGFILE.$(date "+$TIMESTAMP_FORMAT")
    # Redirect stdout/stderr to tee to write the log file
    exec 1> >( tee "${LOGFILE}" ) 2>&1
    echo "stack.sh log $LOGFILE"
    # Specified logfile name always links to the most recent log
    ln -sf $LOGFILE $LOGDIR/$LOGNAME
fi

# So that errors don't compound we exit on any errors so you see only the
# first error that occurred.
trap failed ERR
failed() {
    local r=$?
    set +o xtrace
    [ -n "$LOGFILE" ] && echo "${0##*/} failed: full log in $LOGFILE"
    exit $r
}

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace

# Syslog
# ---------

if [[ $SYSLOG != "False" ]]; then
    apt_get install -y rsyslog-relp
    if [[ "$SYSLOG_HOST" = "$HOST_IP" ]]; then
        # Configure the master host to receive
        cat <<EOF >/tmp/90-stack-m.conf
\$ModLoad imrelp
\$InputRELPServerRun $SYSLOG_PORT
EOF
        sudo mv /tmp/90-stack-m.conf /etc/rsyslog.d
    else
        # Set rsyslog to send to remote host
        cat <<EOF >/tmp/90-stack-s.conf
*.*		:omrelp:$SYSLOG_HOST:$SYSLOG_PORT
EOF
        sudo mv /tmp/90-stack-s.conf /etc/rsyslog.d
    fi
    sudo /usr/sbin/service rsyslog restart
fi

# Mysql
# ---------

if is_service_enabled mysql; then
    sudo service mysql restart
fi


# Horizon
# ---------

# Setup the django horizon application to serve via apache/wsgi

if is_service_enabled horizon; then
    # Initialize the horizon database (it stores sessions and notices shown to
    # users).  The user system is external (keystone).
    cd $HORIZON_DIR/openstack-dashboard
    python manage.py syncdb

    sudo service apache2 restart
fi


# Nova
# ----

# Put config files in /etc/nova for everyone to find
NOVA_CONF=/etc/nova
sudo chown `whoami` $NOVA_CONF

if is_service_enabled n-cpu; then
    sudo /etc/init.d/libvirt-bin restart
fi


# Volume Service
# --------------

if is_service_enabled n-vol; then

    # tgt in oneiric doesn't restart properly if tgtd isn't running
    # do it in two steps
    sudo stop tgt || true
    sudo start tgt
fi

function add_nova_flag {
    echo "$1" >> $NOVA_CONF/nova.conf
}


# Nova Database
# ~~~~~~~~~~~~~

# All nova components talk to a central database.  We will need to do this step
# only once for an entire cluster.

if is_service_enabled mysql; then
    $NOVA_DIR/bin/nova-manage db sync
fi


# Launch Services
# ===============

# nova api crashes if we start it with a regular screen command,
# so send the start command by forcing text into the window.
# Only run the services specified in ``ENABLED_SERVICES``

# Our screenrc file builder
function screen_rc {
    SCREENRC=$TOP_DIR/stack-screenrc
    if [[ ! -e $SCREENRC ]]; then
        # Name the screen session
        echo "sessionname stack" > $SCREENRC
        # Set a reasonable statusbar
        echo 'hardstatus alwayslastline "%-Lw%{= BW}%50>%n%f* %t%{-}%+Lw%< %= %H"' >> $SCREENRC
        echo "screen -t stack bash" >> $SCREENRC
    fi
    # If this service doesn't already exist in the screenrc file
    if ! grep $1 $SCREENRC 2>&1 > /dev/null; then
        NL=`echo -ne '\015'`
        echo "screen -t $1 bash" >> $SCREENRC
        echo "stuff \"$2$NL\"" >> $SCREENRC
    fi
}

# Our screen helper to launch a service in a hidden named screen
function screen_it {
    NL=`echo -ne '\015'`
    if is_service_enabled $1; then
        # Append the service to the screen rc file
        screen_rc "$1" "$2"

        screen -S stack -X screen -t $1
        # sleep to allow bash to be ready to be send the command - we are
        # creating a new window in screen and then sends characters, so if
        # bash isn't running by the time we send the command, nothing happens
        sleep 1.5
        screen -S stack -p $1 -X stuff "$2$NL"
    fi
}

# create a new named screen to run processes in
screen -d -m -S stack -t stack -s /bin/bash
sleep 1
# set a reasonable statusbar
screen -r stack -X hardstatus alwayslastline "%-Lw%{= BW}%50>%n%f* %t%{-}%+Lw%< %= %H"

# launch the glance registry service
if is_service_enabled g-reg; then
    screen_it g-reg "cd $GLANCE_DIR; bin/glance-registry --config-file=etc/glance-registry.conf"
fi

# launch the glance api and wait for it to answer before continuing
if is_service_enabled g-api; then
    screen_it g-api "cd $GLANCE_DIR; bin/glance-api --config-file=etc/glance-api.conf"
    echo "Waiting for g-api ($GLANCE_HOSTPORT) to start..."
    if ! timeout $SERVICE_TIMEOUT sh -c "while ! http_proxy= wget -q -O- http://$GLANCE_HOSTPORT; do sleep 1; done"; then
      echo "g-api did not start"
      exit 1
    fi
fi

if is_service_enabled key; then
    # (re)create keystone database
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS keystone;'
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE keystone;'

    # Configure keystone.conf
    KEYSTONE_CONF=$KEYSTONE_DIR/etc/keystone.conf
    cp $FILES/keystone.conf $KEYSTONE_CONF
    sudo sed -e "s,%SQL_CONN%,$BASE_SQL_CONN/keystone,g" -i $KEYSTONE_CONF
    sudo sed -e "s,%DEST%,$DEST,g" -i $KEYSTONE_CONF
    sudo sed -e "s,%SERVICE_TOKEN%,$SERVICE_TOKEN,g" -i $KEYSTONE_CONF
    sudo sed -e "s,%KEYSTONE_DIR%,$KEYSTONE_DIR,g" -i $KEYSTONE_CONF

    KEYSTONE_CATALOG=$KEYSTONE_DIR/etc/default_catalog.templates
    cp $FILES/default_catalog.templates $KEYSTONE_CATALOG

    # Add swift endpoints to service catalog if swift is enabled
    if is_service_enabled swift; then
        echo "catalog.RegionOne.object_store.publicURL = http://%SERVICE_HOST%:8080/v1/AUTH_\$(tenant_id)s" >> $KEYSTONE_CATALOG
        echo "catalog.RegionOne.object_store.adminURL = http://%SERVICE_HOST%:8080/" >> $KEYSTONE_CATALOG
        echo "catalog.RegionOne.object_store.internalURL = http://%SERVICE_HOST%:8080/v1/AUTH_\$(tenant_id)s" >> $KEYSTONE_CATALOG
        echo "catalog.RegionOne.object_store.name = 'Swift Service'" >> $KEYSTONE_CATALOG
    fi

    # Add quantum endpoints to service catalog if quantum is enabled
    if is_service_enabled quantum; then
        echo "catalog.RegionOne.network.publicURL = http://%SERVICE_HOST%:9696/" >> $KEYSTONE_CATALOG
        echo "catalog.RegionOne.network.adminURL = http://%SERVICE_HOST%:9696/" >> $KEYSTONE_CATALOG
        echo "catalog.RegionOne.network.internalURL = http://%SERVICE_HOST%:9696/" >> $KEYSTONE_CATALOG
        echo "catalog.RegionOne.network.name = 'Quantum Service'" >> $KEYSTONE_CATALOG
    fi

    sudo sed -e "s,%SERVICE_HOST%,$SERVICE_HOST,g" -i $KEYSTONE_CATALOG


    if [ "$SYSLOG" != "False" ]; then
        cp $KEYSTONE_DIR/etc/logging.conf.sample $KEYSTONE_DIR/etc/logging.conf
        sed -i -e '/^handlers=devel$/s/=devel/=production/' \
            $KEYSTONE_DIR/etc/logging.conf
        sed -i -e "/^log_file/s/log_file/\#log_file/" \
            $KEYSTONE_DIR/etc/keystone.conf
        KEYSTONE_LOG_CONFIG="--log-config $KEYSTONE_DIR/etc/logging.conf"
    fi
fi

# launch the keystone and wait for it to answer before continuing
if is_service_enabled key; then
    screen_it key "cd $KEYSTONE_DIR && $KEYSTONE_DIR/bin/keystone-all --config-file $KEYSTONE_CONF $KEYSTONE_LOG_CONFIG -d --debug"
    echo "Waiting for keystone to start..."
    if ! timeout $SERVICE_TIMEOUT sh -c "while ! http_proxy= wget -q -O- $KEYSTONE_SERVICE_PROTOCOL://$KEYSTONE_SERVICE_HOST:$KEYSTONE_SERVICE_PORT/v2.0/; do sleep 1; done"; then
      echo "keystone did not start"
      exit 1
    fi

    # initialize keystone with default users/endpoints
    pushd $KEYSTONE_DIR
    $KEYSTONE_DIR/bin/keystone-manage db_sync
    popd

    # keystone_data.sh creates services, admin and demo users, and roles.
    SERVICE_ENDPOINT=$KEYSTONE_AUTH_PROTOCOL://$KEYSTONE_AUTH_HOST:$KEYSTONE_AUTH_PORT/v2.0
    ADMIN_PASSWORD=$ADMIN_PASSWORD SERVICE_TOKEN=$SERVICE_TOKEN SERVICE_ENDPOINT=$SERVICE_ENDPOINT DEVSTACK_DIR=$TOP_DIR ENABLED_SERVICES=$ENABLED_SERVICES bash $FILES/keystone_data.sh
fi


# launch the nova-api and wait for it to answer before continuing
if is_service_enabled n-api; then
    screen_it n-api "cd $NOVA_DIR && $NOVA_DIR/bin/nova-api"
    echo "Waiting for nova-api to start..."
    if ! timeout $SERVICE_TIMEOUT sh -c "while ! http_proxy= wget -q -O- http://127.0.0.1:8774; do sleep 1; done"; then
      echo "nova-api did not start"
      exit 1
    fi
fi

# Quantum service
if is_service_enabled q-svc; then
    if [[ "$Q_PLUGIN" = "openvswitch" ]]; then
        # Install deps
        # FIXME add to files/apts/quantum, but don't install if not needed!
        apt_get install openvswitch-switch openvswitch-datapath-dkms
        # Create database for the plugin/agent
        if is_service_enabled mysql; then
            mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS ovs_quantum;'
            mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE IF NOT EXISTS ovs_quantum;'
        else
            echo "mysql must be enabled in order to use the $Q_PLUGIN Quantum plugin."
            exit 1
        fi
        QUANTUM_PLUGIN_INI_FILE=$QUANTUM_DIR/etc/plugins.ini
        # Make sure we're using the openvswitch plugin
        sed -i -e "s/^provider =.*$/provider = quantum.plugins.openvswitch.ovs_quantum_plugin.OVSQuantumPlugin/g" $QUANTUM_PLUGIN_INI_FILE
    fi
   screen_it q-svc "cd $QUANTUM_DIR && PYTHONPATH=.:$QUANTUM_CLIENT_DIR:$PYTHONPATH python $QUANTUM_DIR/bin/quantum-server $QUANTUM_DIR/etc/quantum.conf"
fi

# Quantum agent (for compute nodes)
if is_service_enabled q-agt; then
    if [[ "$Q_PLUGIN" = "openvswitch" ]]; then
        # Set up integration bridge
        OVS_BRIDGE=${OVS_BRIDGE:-br-int}
        sudo ovs-vsctl --no-wait -- --if-exists del-br $OVS_BRIDGE
        sudo ovs-vsctl --no-wait add-br $OVS_BRIDGE
        sudo ovs-vsctl --no-wait br-set-external-id $OVS_BRIDGE bridge-id br-int

       # Start up the quantum <-> openvswitch agent
       QUANTUM_OVS_CONFIG_FILE=$QUANTUM_DIR/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
       sed -i -e "s/^sql_connection =.*$/sql_connection = mysql:\/\/$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST\/ovs_quantum/g" $QUANTUM_OVS_CONFIG_FILE
       screen_it q-agt "sleep 4; sudo python $QUANTUM_DIR/quantum/plugins/openvswitch/agent/ovs_quantum_agent.py $QUANTUM_OVS_CONFIG_FILE -v"
    fi

fi

# Melange service
if is_service_enabled m-svc; then
    if is_service_enabled mysql; then
        mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS melange;'
        mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE melange;'
    else
        echo "mysql must be enabled in order to use the $Q_PLUGIN Quantum plugin."
        exit 1
    fi
    MELANGE_CONFIG_FILE=$MELANGE_DIR/etc/melange/melange.conf
    cp $MELANGE_CONFIG_FILE.sample $MELANGE_CONFIG_FILE
    sed -i -e "s/^sql_connection =.*$/sql_connection = mysql:\/\/$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST\/melange/g" $MELANGE_CONFIG_FILE
    cd $MELANGE_DIR && PYTHONPATH=.:$PYTHONPATH python $MELANGE_DIR/bin/melange-manage --config-file=$MELANGE_CONFIG_FILE db_sync
    screen_it m-svc "cd $MELANGE_DIR && PYTHONPATH=.:$PYTHONPATH python $MELANGE_DIR/bin/melange-server --config-file=$MELANGE_CONFIG_FILE"
    echo "Waiting for melange to start..."
    if ! timeout $SERVICE_TIMEOUT sh -c "while ! http_proxy= wget -q -O- http://127.0.0.1:9898; do sleep 1; done"; then
      echo "melange-server did not start"
      exit 1
    fi
    melange mac_address_range create cidr=$M_MAC_RANGE
fi


# Launching nova-compute should be as simple as running ``nova-compute`` but
# have to do a little more than that in our script.  Since we add the group
# ``libvirtd`` to our user in this script, when nova-compute is run it is
# within the context of our original shell (so our groups won't be updated).
# Use 'sg' to execute nova-compute as a member of the libvirtd group.
screen_it n-cpu "cd $NOVA_DIR && sg libvirtd $NOVA_DIR/bin/nova-compute"
screen_it n-crt "cd $NOVA_DIR && $NOVA_DIR/bin/nova-cert"
screen_it n-obj "cd $NOVA_DIR && $NOVA_DIR/bin/nova-objectstore"
screen_it n-vol "cd $NOVA_DIR && $NOVA_DIR/bin/nova-volume"
screen_it n-net "cd $NOVA_DIR && $NOVA_DIR/bin/nova-network"
screen_it n-sch "cd $NOVA_DIR && $NOVA_DIR/bin/nova-scheduler"
if is_service_enabled n-novnc; then
    screen_it n-novnc "cd $NOVNC_DIR && ./utils/nova-novncproxy --flagfile $NOVA_CONF/nova.conf --web ."
fi
if is_service_enabled n-xvnc; then
    screen_it n-xvnc "cd $NOVA_DIR && ./bin/nova-xvpvncproxy --flagfile $NOVA_CONF/nova.conf"
fi
if is_service_enabled n-cauth; then
    screen_it n-cauth "cd $NOVA_DIR && ./bin/nova-consoleauth"
fi
if is_service_enabled horizon; then
    screen_it horizon "cd $HORIZON_DIR && sudo tail -f /var/log/apache2/error.log"
fi

# Install Images
# ==============

# Upload an image to glance.
#
# The default image is a small ***TTY*** testing image, which lets you login
# the username/password of root/password.
#
# TTY also uses cloud-init, supporting login via keypair and sending scripts as
# userdata.  See https://help.ubuntu.com/community/CloudInit for more on cloud-init
#
# Override ``IMAGE_URLS`` with a comma-separated list of uec images.
#
#  * **natty**: http://uec-images.ubuntu.com/natty/current/natty-server-cloudimg-amd64.tar.gz
#  * **oneiric**: http://uec-images.ubuntu.com/oneiric/current/oneiric-server-cloudimg-amd64.tar.gz


# Fin
# ===

set +o xtrace

# Using the cloud
# ===============

echo ""
echo ""
echo ""

# If you installed the horizon on this server, then you should be able
# to access the site using your browser.
if is_service_enabled horizon; then
    echo "horizon is now available at http://$SERVICE_HOST/"
fi

# If keystone is present, you can point nova cli to this server
if is_service_enabled key; then
    echo "keystone is serving at $KEYSTONE_SERVICE_PROTOCOL://$KEYSTONE_SERVICE_HOST:$KEYSTONE_SERVICE_PORT/v2.0/"
    echo "examples on using novaclient command line is in exercise.sh"
    echo "the default users are: admin and demo"
    echo "the password: $ADMIN_PASSWORD"
fi

# Echo HOST_IP - useful for build_uec.sh, which uses dhcp to give the instance an address
echo "This is your host ip: $HOST_IP"
echo "mount shared instance dir"
sudo mount -t nfs $MYSQL_HOST:/srv/instances $NOVA_DIR/instances
# Indicate how long this took to run (bash maintained variable 'SECONDS')
echo "stack.sh completed in $SECONDS seconds."
