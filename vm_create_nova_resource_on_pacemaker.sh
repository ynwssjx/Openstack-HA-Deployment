#!/usr/bin/bash


section=`hostname`
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
keystone_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default keystone_secret)
internal_network=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy internal_network)
master=$(/usr/bin/bash readini.sh cluster_variables.ini default master)


vip_db=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-db)
vip_rabbitmq=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-rabbitmq)
vip_qpid=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-qpid)
vip_keystone=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-keystone)
vip_glance=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-glance)
vip_cinder=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-cinder)
vip_swift=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-swift)
vip_neutron=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-neutron)
vip_nova=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-nova)
vip_horizon=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-horizon)
vip_heat=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-heat)
vip_ceilometer=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-ceilomete)




su nova -s /bin/sh -c "nova-manage db sync"
if [ $? -eq 0 ]
	then
	echo "nova db sync successful!"
else
	echo "nova db sync failed!"
	exit
fi

pcs resource delete nova-consoleauth --force
pcs resource delete nova-novncproxy --force
pcs resource delete nova-api --force
pcs resource delete nova-scheduler --force
pcs resource delete nova-conductor --force
pcs resource delete nova-cert --force

pcs resource create nova-consoleauth systemd:openstack-nova-consoleauth --clone interleave=true
pcs resource create nova-novncproxy systemd:openstack-nova-novncproxy --clone interleave=true
pcs resource create nova-api systemd:openstack-nova-api --clone interleave=true
pcs resource create nova-scheduler systemd:openstack-nova-scheduler --clone interleave=true
pcs resource create nova-conductor systemd:openstack-nova-conductor --clone interleave=true
pcs resource create nova-cert systemd:openstack-nova-cert --clone interleave=true


pcs constraint order start nova-consoleauth-clone then nova-novncproxy-clone
pcs constraint colocation add nova-novncproxy-clone with nova-consoleauth-clone

pcs constraint order start nova-novncproxy-clone then nova-api-clone
pcs constraint colocation add nova-api-clone with nova-novncproxy-clone

pcs constraint order start nova-api-clone then nova-cert-clone
pcs constraint colocation add nova-cert-clone with nova-api-clone

pcs constraint order start nova-api-clone then nova-scheduler-clone
pcs constraint colocation add nova-scheduler-clone with nova-api-clone

pcs constraint order start nova-scheduler-clone then nova-conductor-clone
pcs constraint colocation add nova-conductor-clone with nova-scheduler-clone


pcs constraint order start keystone-clone then nova-consoleauth-clone

loop=0; while ! nova list > /dev/null 2>&1 && [ "$loop" -lt 60 ]; do
	echo waiting nova to be stable
	loop=$((loop + 1))
	sleep 5
done

nova keypair-add admin-key > admin-key.rsa
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

nova keypair-list
nova list

