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




# su cinder -s /bin/sh -c "cinder-manage db sync"
su -s /bin/sh -c "cinder-manage db sync" cinder

# create services in pacemaker
pcs resource delete cinder-api --force
pcs resource delete cinder-scheduler --force
pcs resource create cinder-api systemd:openstack-cinder-api --clone interleave=true
pcs resource create cinder-scheduler systemd:openstack-cinder-scheduler --clone interleave=true

# Volume must be A/P for now. See https://bugzilla.redhat.com/show_bug.cgi?id=1193229
pcs resource delete cinder-volume --force
pcs resource create cinder-volume systemd:openstack-cinder-volume

pcs constraint order start cinder-api-clone then cinder-scheduler-clone
pcs constraint colocation add cinder-scheduler-clone with cinder-api-clone
pcs constraint order start cinder-scheduler-clone then cinder-volume
pcs constraint colocation add cinder-volume with cinder-scheduler-clone

pcs constraint order start keystone-clone then cinder-api-clone

source /root/adminrc
loop=0; while ! cinder list > /dev/null 2>&1 && [ "$loop" -lt 60 ]; do
	echo waiting cinder to be stable
	loop=$((loop + 1))
	sleep 5
done

cinder create --display-name volume1 2
cinder list