#!/usr/bin/bash

compute_num=$(/usr/bin/bash readini.sh cluster_variables.ini computer node_num)
int_ip_set=$(/usr/bin/bash readini.sh cluster_variables.ini computer inter_ip_set)
ext_ip_set=$(/usr/bin/bash readini.sh cluster_variables.ini computer ext_ip_set)
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
master=$(/usr/bin/bash readini.sh cluster_variables.ini default master)

NFS_SERVER=`hostname`

for ((i=1;i<=$compute_num;i++))
do
	int_ip=$(echo $int_ip_set|cut -d ";" -f $i)
	scp openstack_compute* $int_ip:/root
	scp cluster_variables.ini $int_ip:/root
    scp readini.sh $int_ip:/root
    # scp NovaCompute NovaEvacuate $int_ip:/usr/lib/ocf/resource.d/heartbeat/

    ssh $int_ip "ls -l /etc/openstack-kilo_tag/compute_node_install_nova.tag"
    if [ $? -eq 0 ]
    	then
    	echo -e "\033[41;37m This compute node already configured as nova-compute node,we will process next node! \033[0m"
    	continue
    fi

    echo -e "\033[41;37m beging install nova-compute on ${i}th compute node ! \033[0m"
    ssh $int_ip "/usr/bin/bash openstack_compute_node_nova_install_and_config.sh"
done

for i in 1 2 3
do
	scp readini.sh cluster_variables.ini ${ip_node[$i]}:/root
	# scp NovaCompute NovaEvacuate ${ip_node[$i]}:/usr/lib/ocf/resource.d/heartbeat/
	scp openstack_compute* ${ip_node[$i]}:/root
done


echo "beging create pacemaker_remote resource on master controller node!"
ssh ${ip_node[1]} "/usr/bin/bash openstack_compute_create_pacemaker_remote_resource.sh"
