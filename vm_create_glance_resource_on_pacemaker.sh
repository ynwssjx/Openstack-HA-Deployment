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

# Now have pacemaker mount the NFS share as service.
pcs resource delete glance-fs
pcs resource create glance-fs Filesystem  device="$master:/data/glance" directory="/var/lib/glance"  fstype="nfs" options="v3" --clone

# wait for glance-fs to be started and running
sleep 5

# Make sure it's writable
chown glance:nobody /var/lib/glance

# Now populate the database
su glance -s /bin/sh -c "glance-manage db_sync"

pcs resource delete glance-api
pcs resource delete glance-registry
pcs resource create glance-registry systemd:openstack-glance-registry --clone interleave=true
pcs resource create glance-api systemd:openstack-glance-api --clone interleave=true

pcs constraint order start glance-fs-clone then glance-registry-clone
pcs constraint colocation add glance-registry-clone with glance-fs-clone
pcs constraint order start glance-registry-clone then glance-api-clone
pcs constraint colocation add glance-api-clone with glance-registry-clone

pcs constraint order start keystone-clone then glance-registry-clone


source /root/adminrc
loop=0; while ! glance image-list > /dev/null 2>&1 && [ "$loop" -lt 60 ]; do
	echo waiting glance to be stable
	loop=$((loop + 1))
	sleep 5
done
glance image-create --container-format bare --disk-format qcow2 --is-public true --file cirros-0.3.4-x86_64-disk.img --name cirros --progress

glance image-list
