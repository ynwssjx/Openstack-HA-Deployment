#!/usr/bin/bash

ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
keystone_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default keystone_secret)
rabbitmq_hosts=$(/usr/bin/bash readini.sh cluster_variables.ini default rabbitmq_hosts)
master=$(/usr/bin/bash readini.sh cluster_variables.ini default master)
memcaches=$(/usr/bin/bash readini.sh cluster_variables.ini default memcaches)
nfs_dir=$(/usr/bin/bash readini.sh cluster_variables.ini default share_dir)
metadata_shared_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default neutron_metadata_shared_secret)
compute_nodes=$(/usr/bin/bash readini.sh cluster_variables.ini computer compute_nodes)
nodes_num=$(/usr/bin/bash readini.sh cluster_variables.ini computer node_num)

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


# if [ ! -f /etc/openstack-kilo_tag/compute_node_install_nova.tag ]
# 	then
# 	echo "you must be install nova-compute software before run this script!"
# 	exit
# fi





#To aviod repeat create resource,delete any reousrce to create on this script
pcs resource delete nova-evacuate --force
pcs resource delete neutron-openvswitch-agent-compute --force 
pcs resource delete libvirtd-compute --force 
pcs resource delete ceilometer-compute --force 
pcs resource delete nova-compute-fs --force 
pcs resource delete nova-compute --force 
pcs stonith delete fence-nova --force


# add NovaEvacuate. It must be A/P and that is perfectly acceptable to avoid need of a cluster wide locking
pcs resource create nova-evacuate ocf:openstack:NovaEvacuate auth_url=http://$vip_keystone:35357 username=admin password=admin tenant_name=admin

# without any of those services, nova-evacuate is useless
# later we also add a order start on nova-compute (after -compute is defined)

for i in vip-glance vip-cinder vip-neutron vip-nova vip-db vip-rabbitmq vip-keystone cinder-volume; do
 pcs constraint order start $i then nova-evacuate
done

for i in glance-api-clone neutron-metadata-agent-clone nova-conductor-clone; do
  pcs constraint order start $i then nova-evacuate require-all=false
done

# Take down the ODP control plane,wait 8min
# pcs resource disable keystone --wait=600

# Take advantage of the fact that control nodes will already be part of the cluster
# At this step, we need to teach the cluster about the compute nodes
#
# This requires running commands on the cluster based on the names of the compute nodes

controllers=$(cibadmin -Q -o nodes | grep uname | sed s/.*uname..// | awk -F\" '{print $1}'|grep -v comput*)

for controller in ${controllers}; do
    pcs property set --node ${controller} osprole=controller
done

# Force services to run only on nodes with osprole = controller
#
# Importantly it also tells Pacemaker not to even look for the services on other
# nodes. This helps reduce noise and collisions with services that fill the same role
# on compute nodes.

stonithdevs=$(pcs stonith | awk '{print $1}')

for i in $(cibadmin -Q --xpath //primitive --node-path | tr ' ' '\n' | awk -F "id='" '{print $2}' | awk -F "'" '{print $1}' | uniq); do
    found=0
    if [ -n "$stonithdevs" ]; then
	for x in $stonithdevs; do
	    if [ $x = $i ]; then
		found=1
	    fi
	done
    fi
    if [ $found = 0 ]; then
	pcs constraint location $i rule resource-discovery=exclusive score=0 osprole eq controller --force
    fi
done

# Now (because the compute nodes have roles assigned to them and keystone is
# stopped) it is safe to define the services that will run on the compute nodes

# neutron-openvswitch-agent
pcs resource create neutron-openvswitch-agent-compute systemd:neutron-openvswitch-agent --clone interleave=true --disabled --force
pcs constraint location neutron-openvswitch-agent-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute 

pcs constraint order start neutron-server-api-clone then neutron-openvswitch-agent-compute-clone require-all=false

# libvirtd
pcs resource create libvirtd-compute systemd:libvirtd --clone interleave=true --disabled --force
pcs constraint location libvirtd-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute

pcs constraint order start neutron-openvswitch-agent-compute-clone then libvirtd-compute-clone
pcs constraint colocation add libvirtd-compute-clone with neutron-openvswitch-agent-compute-clone

# openstack-ceilometer-compute
pcs resource create ceilometer-compute systemd:openstack-ceilometer-compute --clone interleave=true --disabled --force
pcs constraint location ceilometer-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute

pcs constraint order start ceilometer-notification-clone then ceilometer-compute-clone require-all=false

pcs constraint order start libvirtd-compute-clone then ceilometer-compute-clone
pcs constraint colocation add ceilometer-compute-clone with libvirtd-compute-clone

# nfs mount for nova-compute shared storage
pcs resource create nova-compute-fs Filesystem  device="$master:$nfs_dir/instances" directory="/var/lib/nova/instances" fstype="nfs" options="v3" op start timeout=240 --clone interleave=true --disabled --force
pcs constraint location nova-compute-fs-clone rule resource-discovery=exclusive score=0 osprole eq compute

pcs constraint order start ceilometer-compute-clone then nova-compute-fs-clone
pcs constraint colocation add nova-compute-fs-clone with ceilometer-compute-clone

# nova-compute
pcs resource create nova-compute ocf:openstack:NovaCompute auth_url=http://$vip_keystone:35357 username=admin password=admin tenant_name=admin op start timeout=300 --clone interleave=true --disabled --force
#pcs resource create nova-compute ocf:openstack:NovaCompute auth_url=http://192.168.142.203:35357 username=admin password=admin tenant_name=admin op start timeout=300 --clone interleave=true --disabled --force
pcs constraint location nova-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute

pcs constraint order start nova-conductor-clone then nova-compute-clone require-all=false

pcs constraint order start nova-compute-fs-clone then nova-compute-clone require-all=false
pcs constraint colocation add nova-compute-clone with nova-compute-fs-clone
pcs constraint colocation add nova-compute-clone with libvirtd-compute-clone

pcs constraint order start libvirtd-compute-clone then nova-compute-clone require-all=false
pcs constraint order start nova-compute-clone then nova-evacuate require-all=false

#set stonith device
# case ${PHD_VAR_network_hosts_gateway} in
#     east-*)
# 	pcs stonith create fence-compute fence_apc ipaddr=east-apc login=apc passwd=apc pcmk_host_map="east-01:2;east-02:3;east-03:4;east-04:5;east-05:6;east-06:7;east-07:9;east-08:10;east-09:11;east-10:12;east-11:13;east-12:14;east-13:15;east-14:18;east-15:17;east-16:19;" --force
#     ;;
#     mrg-*)
# 	pcs stonith create fence-compute fence_apc_snmp ipaddr=apc-ap7941-l2h3.mgmt.lab.eng.bos.redhat.com power_wait=10 pcmk_host_map="mrg-07:10;mrg-08:12;mrg-09:14"
#     ;;
# esac


pcs stonith create fence-nova fence_compute auth-url=http://$vip_keystone:35357 login=admin passwd=admin tenant-name=admin  record-only=1 action=off --force

# while this is set in basic.cluster, it looks like OSPd doesn't set it.
pcs resource defaults resource-stickiness=INFINITY

# allow compute nodes to rejoin the cluster automatically
# 1m might be a bit aggressive tho
pcs property set cluster-recheck-interval=1min

# delete ";" from variable compute_nodes
compute_node=$(echo $compute_nodes|awk -F ";" '{\
for (i=1;i<=NF;i++)
{
print $i;
}
}')


for node in $(echo $compute_node|cut -d " " -f -$nodes_num)
do
	pcs resoure delete $node --force 
	pcs resource create $node ocf:pacemaker:remote reconnect_interval=60 op monitor interval=20
	# pcs resource create $node ocf:pacemaker:remote
	pcs property set --node $node osprole=compute
	# pcs stonith level add 1 $node fence-compute,fence-nova
done


# for node in ${PHD_ENV_nodes}; do
#     found=0
#     short_node=$(echo ${node} | sed s/\\..*//g)

#     for controller in ${controllers}; do
# 	if [ ${short_node} = ${controller} ]; then
# 	    found=1
# 	fi
#     done

#     if [ $found = 0 ]; then
# 	# We only want to execute the following _for_ the compute nodes, not _on_ the controller nodes
# 	# Rather annoying

# 	pcs resource create ${short_node} ocf:pacemaker:remote reconnect_interval=60 op monitor interval=20
# 	pcs property set --node ${short_node} osprole=compute
# 	pcs stonith level add 1 ${short_node} fence-compute,fence-nova
#     fi
# done

pcs resource enable keystone
pcs resource enable neutron-openvswitch-agent-compute
pcs resource enable libvirtd-compute
pcs resource enable ceilometer-compute
pcs resource enable nova-compute-fs
pcs resource enable nova-compute

# cleanup after us
sleep 60
# pcs resource cleanup
pcs status
