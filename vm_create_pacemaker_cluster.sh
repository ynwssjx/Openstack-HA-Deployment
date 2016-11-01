#!/usr/bin/bash 

# function of this script:
# 1.check if cluster software already instanlled on everyone nodes
# 2.make ssh credit between controller1-vm and controller2-vm,controller3-vm
# 3.initial pacemaker cluster,auth and create cluster
# 4.config stonith device in pacemaker cluster

function log_info ()
#log function
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/create_pacemaker_cluster.log.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/create_pacemaker_cluster.log.log

}

function fn_log () 
{
if [  $? -eq 0  ]
then
	log_info "$@ successful."
	echo -e "\033[32m $@ successful. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}

fence_xvm=$(/usr/bin/bash readini.sh cluster_variables.ini default fence_xvm)
ntp_server=$(/usr/bin/bash readini.sh cluster_variables.ini default master)
hacluster_passwd=$(/usr/bin/bash readini.sh cluster_variables.ini default hacluster_passwd)
ha_cluster_node_num=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_node_num)
hacluster_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
hacluster_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
hacluster_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)
ha_cluster_name=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_name)

rpm -aq|grep pacemaker
if [ $? -gt 0 ] || [ $? -lt 0 ]
	then
	echo "please call vm_install_cluster_software_on_all_nodes.sh to install cluster software first"
	exit
fi

# Construct and start the cluster
# The cluster needs a unique name, we set the first node's name as cluster name
nodes_list=""
for (( i = 1; i <= $ha_cluster_node_num; i++ )); do
	nodes_list="$nodes_list ${hacluster_node[i]}"
done

yum install -y expect
expect << EOT
set timeout 2
spawn ssh-keygen -t rsa 
expect {
	"*to save the key" {send "\n";exp_continue}
	"*(y/n)" {send "y\r";exp_continue}
	"Enter passphrase" {send "\n";exp_continue}
	"Enter same passphrase" {send "\n";exp_continue}
}
EOT
echo $hacluster_passwd|passwd --stdin hacluster
for i in `echo $nodes_list|awk '{print $2,$3}'`
do
expect << EOF
	set timeout 2
	spawn ssh-copy-id root@$i 
	expect {
		"yes/no" {send "yes\r";exp_continue}
	    "password" {send "root\r";exp_continue}
}
EOF
ssh root@$i "echo $hacluster_passwd|passwd --stdin hacluster"
done

pcs cluster auth $nodes_list -u hacluster -p ${hacluster_passwd} --force
pcs cluster setup --force --name $ha_cluster_name  $nodes_list
pcs cluster enable --all
pcs cluster start --all
sleep 5

pcs stonith create fence1 fence_xvm multicast_address=225.0.0.1
pcs stonith create fence2 fence_xvm multicast_address=225.0.0.2
pcs stonith create fence3 fence_xvm multicast_address=225.0.0.3

pcs resource defaults resource-stickiness=INFINITY