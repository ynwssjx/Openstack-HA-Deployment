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
vip_redis=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy vip-redis)





su heat -s /bin/sh -c "heat-manage db_sync"

pcs resource delete heat-api  --force
pcs resource delete heat-api-cfn --force
pcs resource delete heat-api-cloudwatch  --force
pcs resource delete heat-engine --force

pcs resource create heat-api systemd:openstack-heat-api --clone interleave=true
pcs resource create heat-api-cfn systemd:openstack-heat-api-cfn  --clone interleave=true
pcs resource create heat-api-cloudwatch systemd:openstack-heat-api-cloudwatch --clone interleave=true
pcs resource create heat-engine systemd:openstack-heat-engine --clone interleave=true

pcs constraint order start heat-api-clone then heat-api-cfn-clone
pcs constraint colocation add heat-api-cfn-clone with heat-api-clone
pcs constraint order start heat-api-cfn-clone then heat-api-cloudwatch-clone
pcs constraint colocation add heat-api-cloudwatch-clone with heat-api-cfn-clone
pcs constraint order start heat-api-cloudwatch-clone then heat-engine-clone
pcs constraint colocation add heat-engine-clone with heat-api-cloudwatch-clone

pcs constraint order start ceilometer-notification-clone then heat-api-clone
