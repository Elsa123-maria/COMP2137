#!/bin/bash
# This script runs the configure-host.sh script from the current directory
# to modify 2 servers and update the local /etc/hosts file

# to enable verbose if passed
VERBOSE=""
if [[ "$1" == "-verbose" ]]; then
    VERBOSE="-verbose"
    echo " Verbose mode enabled."
fi

# In order to function to deploy to a server
deploy_to_server() {
    SERVER=$1
    HOSTNAME=$2
    IP=$3
    HOSTENTRY_NAME=$4
    HOSTENTRY_IP=$5

    echo " Copying configure-host.sh to $SERVER..."
     if ! scp configure-host.sh remoteadmin@"$SERVER":/root; then 
        echo "Oops!! SCP to $SERVER failed!"
        exit 1
    
     fi
    echo " Running configuration on $SERVER..."
     if ! ssh remoteadmin@"$SERVER" -- "/root/configure-host.sh $VERBOSE -name $HOSTNAME -ip $IP -hostentry $HOSTENTRY_NAME $HOSTENTRY_IP"; then
        echo " SSH execution on $SERVER failed!"
        exit 1
     fi
}

# Deploy to server1-mgmt
deploy_to_server "server1-mgmt" "loghost" "192.168.16.3" "webhost" "192.168.16.4"

# Deploy to server2-mgmt
deploy_to_server "server2-mgmt" "webhost" "192.168.16.4" "loghost" "192.168.16.3"

# Update local /etc/hosts
echo "Updating local /etc/hosts on desktop VM..."
sudo ./configure-host.sh $VERBOSE -hostentry loghost 192.168.16.3
sudo ./configure-host.sh $VERBOSE -hostentry webhost 192.168.16.4

echo " All hosts configured successfully."
