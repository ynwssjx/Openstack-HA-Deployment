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





# source adminrc

# required when installing the DB manually
# neutron-db-manage --config-file /usr/share/neutron/neutron-dist.conf --config-file  /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade kilo
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
if [ $? -eq 0 ]
	then
	echo "neutron-db-manage is successful!"
else
	echo "neutron-db-manage is failed!"
	exit
fi

systemctl start neutron-server
if [ $? -eq 0 ]
	then
	echo "neutron start is successful and we will stop it"
else
	echo "neutron start is failed!"
	exit
fi
systemctl stop neutron-server

# add the service to pacemaker
# pcs resource delete neutron-server
pcs resource delete neutron-server-api --force
pcs resource delete neutron-scale --force
pcs resource delete neutron-ovs-cleanup --force
pcs resource delete neutron-netns-cleanup --force
pcs resource delete neutron-openvswitch-agent --force
pcs resource delete neutron-dhcp-agent --force
pcs resource delete neutron-l3-agent --force
pcs resource delete neutron-metadata-agent --force

pcs resource create neutron-server-api systemd:neutron-server op start timeout=180 --clone interleave=true
# For A/P, set clone-max=1
pcs resource create neutron-scale ocf:neutron:NeutronScale --clone globally-unique=true clone-max=3 interleave=true
pcs resource create neutron-ovs-cleanup ocf:neutron:OVSCleanup --clone interleave=true
pcs resource create neutron-netns-cleanup ocf:neutron:NetnsCleanup --clone interleave=true
pcs resource create neutron-openvswitch-agent  systemd:neutron-openvswitch-agent --clone interleave=true
pcs resource create neutron-dhcp-agent systemd:neutron-dhcp-agent --clone interleave=true
pcs resource create neutron-l3-agent systemd:neutron-l3-agent --clone interleave=true
pcs resource create neutron-metadata-agent systemd:neutron-metadata-agent  --clone interleave=true

pcs constraint order start keystone-clone then neutron-server-api-clone
pcs constraint order start neutron-scale-clone then neutron-openvswitch-agent-clone
pcs constraint colocation add neutron-openvswitch-agent-clone with neutron-scale-clone
pcs constraint order start neutron-scale-clone then neutron-ovs-cleanup-clone
pcs constraint colocation add neutron-ovs-cleanup-clone with neutron-scale-clone

# pcs constraint order start neutron-server-api-clone then neutron-ovs-cleanup-clone
# pcs constraint colocation add neutron-ovs-cleanup-clone with neutron-server-api-clone

pcs constraint order start neutron-ovs-cleanup-clone then neutron-netns-cleanup-clone
pcs constraint colocation add neutron-netns-cleanup-clone with neutron-ovs-cleanup-clone
pcs constraint order start neutron-netns-cleanup-clone then neutron-openvswitch-agent-clone
pcs constraint colocation add neutron-openvswitch-agent-clone with neutron-netns-cleanup-clone
pcs constraint order start neutron-openvswitch-agent-clone then neutron-dhcp-agent-clone
pcs constraint colocation add neutron-dhcp-agent-clone with neutron-openvswitch-agent-clone
pcs constraint order start neutron-dhcp-agent-clone then neutron-l3-agent-clone
pcs constraint colocation add neutron-l3-agent-clone with neutron-dhcp-agent-clone
pcs constraint order start neutron-l3-agent-clone then neutron-metadata-agent-clone
pcs constraint colocation add neutron-metadata-agent-clone with neutron-l3-agent-clone
pcs constraint order start neutron-server-api-clone then neutron-scale-clone
pcs constraint order start keystone-clone then neutron-scale-clone
 

source /root/adminrc
loop=0; while ! neutron net-list > /dev/null 2>&1 && [ "$loop" -lt 60 ]; do
	echo waiting neutron to be stable
	loop=$((loop + 1))
	sleep 5
done


if neutron router-list
	then
	neutron router-gateway-clear admin-router ext-net
	neutron router-interface-delete admin-router admin-subnet
	neutron router-delete admin-router
	neutron subnet-delete admin-subnet
	neutron subnet-delete ext-subnet
	neutron net-delete admin-net
	neutron net-delete ext-net
fi

neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat
neutron subnet-create ext-net 192.168.115.0/24 --name ext-subnet --allocation-pool start=192.168.115.200,end=192.168.115.250  --disable-dhcp --gateway 192.168.115.254
neutron net-create admin-net
neutron subnet-create admin-net 192.128.1.0/24 --name admin-subnet --gateway 192.128.1.1
neutron router-create admin-router
neutron router-interface-add admin-router admin-subnet 
neutron router-gateway-set admin-router ext-net


