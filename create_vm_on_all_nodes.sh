#!/usr/bin/bash

#functions of this scripts:
# 1.create guest vm on master control node
# 2.create guest vm on slave nodes 
# 3.set all node /etc/hosts entry include guest 
# 4.set ssh credit between all guests and master node



function log_info ()
#log function
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/openstack_all_nodes_vm_create.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/openstack_all_nodes_vm_create.log

}

function fn_log ()  {
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


###############################start create vm on all nodes#####################
slave_node_num=$(/usr/bin/bash readini.sh cluster_variables.ini default slave_ctr_node_num) 

ip_master=$(/usr/bin/bash readini.sh cluster_variables.ini default ip_master)
master_vm_name=$(/usr/bin/bash readini.sh cluster_variables.ini default master)-vm
master_vm_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $master_vm_name int_ip)

for ((i=1;i<=${slave_node_num};i++))
{
	ip_slave[i]=$(/usr/bin/bash readini.sh cluster_variables.ini default ip_slave${i})
	vm_name_slave[i]=$(/usr/bin/bash readini.sh cluster_variables.ini default slave${i})-vm 
    vm_ip_slave[i]=$(/usr/bin/bash readini.sh cluster_variables.ini ${vm_name_slave[i]} int_ip)
    # echo "${ip_slave[i]}"
    # echo "${vm_name_slave[i]}"
    # echo "${vm_ip_slave[i]}"

}


echo "beging create vm on master nodes,it takes about 15 minutes"
/usr/bin/bash create_vm_on_master_node.sh
fn_log "create vm on master"


sed -i '/$*-vm/d' /etc/hosts
echo "$master_vm_ip $master_vm_name" >> /etc/hosts
for ((i=1;i<=$slave_node_num;i++))
do
	scp create_vm_on_slave_nodes.sh ${ip_slave[i]}:/root
	scp cluster_variables.ini ${ip_slave[i]}:/root
	echo "beging create vm on slave${i} node"
	ssh root@${ip_slave[i]} "/usr/bin/bash create_vm_on_slave_nodes.sh"
	fn_log "create vm on slave${i} node"
	echo "${vm_ip_slave[i]} ${vm_name_slave[i]}" >> /etc/hosts
done

expect << EOT
spawn ssh-copy-id root@$master_vm_ip
    expect {
         "yes/no" {send "yes\r";exp_continue}
 	     "password" {send "root\r";exp_continue}
 }
EOT
ssh root@$master_vm_ip "hostnamectl set-hostname $master_vm_name"
scp /etc/hosts $master_vm_ip:/etc/
virsh list |grep running

for ((i=1;i<=$slave_node_num;i++))
{
	
	expect << EOF
    set timeout 2
    spawn ssh-copy-id root@${vm_ip_slave[i]}
    expect {
         "yes/no" {send "yes\r";exp_continue}
 	     "password" {send "root\r";exp_continue}
 }
EOF
 ssh root@${vm_ip_slave[i]} "hostnamectl set-hostname ${vm_name_slave[i]}"
 scp /etc/hosts ${ip_slave[i]}:/etc/
 scp /etc/hosts ${vm_ip_slave[i]}:/etc/
 ssh root@${ip_slave[i]} "virsh list |grep running"
}


