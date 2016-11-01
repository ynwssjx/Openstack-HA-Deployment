#!/usr/bin/bash


#redis-2.8 has not resource agent ,so we download ocf:heartbeat:redis script from https://github.com/ClusterLabs/resource-agents/blob/master/heartbeat/redis

for i in `more /etc/hosts|grep vm|awk -F " " '{print $2}'`
do
	scp readini.sh $i:/root
	scp cluster_variables.ini $i:/root
	scp /etc/hosts $i:/etc/
	scp vm* $i:/root
	scp ocf_heartbeat_redis.sh $i:/usr/lib/ocf/resource.d/heartbeat/redis
done

hacluster_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
hacluster_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
hacluster_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)
ha_cluster_node_num=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_node_num)
master_vm_name=$(/usr/bin/bash readini.sh cluster_variables.ini default master)-vm
master_vm_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $master_vm_name int_ip)

for (( i = 1; i <=$ha_cluster_node_num; i++ ))
do
	echo "beging install ceilometer on ${hacluster_node[i]}"
	ssh root@${hacluster_node[i]} "/usr/bin/bash vm_install_ceilometer_and_config.sh"
done

echo "create ceilometer resource on pacemaker"
ssh root@$master_vm_name "/usr/bin/bash vm_create_ceilometer_resource_on_pacemaker.sh"
sleep 10
ssh root@$master_vm_name "pcs status"


