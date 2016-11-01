#!/usr/bin/bash

# function of this script:
# 1.call vm_install_cluster_software_on_all_nodes script to install and config cluster env on everyone guest node
# 2.call vm_create_pacemaker_cluster script to create and start pacemaker cluster



for i in `more /etc/hosts|grep vm|awk -F " " '{print $2}'`
do
	scp readini.sh $i:/root
	scp cluster_variables.ini $i:/root
	scp /etc/hosts $i:/etc/
done


fence_xvm=$(/usr/bin/bash readini.sh cluster_variables.ini default fence_xvm)
ntp_server=$(/usr/bin/bash readini.sh cluster_variables.ini default master)
hacluster_passwd=$(/usr/bin/bash readini.sh cluster_variables.ini default hacluster_passwd)
ha_cluster_node_num=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_node_num)
hacluster_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
hacluster_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
hacluster_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)
ha_cluster_name=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_name)
slave_node_num=$(/usr/bin/bash readini.sh cluster_variables.ini default slave_ctr_node_num) 
ip_master=$(/usr/bin/bash readini.sh cluster_variables.ini default ip_master)
master_vm_name=$(/usr/bin/bash readini.sh cluster_variables.ini default master)-vm
master_vm_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $master_vm_name int_ip)

for (( i = 1; i <= $ha_cluster_node_num; i++ )); do
	
	scp vm* ${hacluster_node[i]}:/root
    echo "beging install pacemaker on ${hacluster_node[i]}"
	ssh root@${hacluster_node[i]} "/usr/bin/bash vm_install_cluster_software_on_all_nodes.sh"

done

ssh root@$master_vm_name "/usr/bin/bash vm_create_pacemaker_cluster.sh"
sleep 10
ssh root@$master_vm_name "pcs status"










