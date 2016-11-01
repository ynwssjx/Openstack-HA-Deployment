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


pcs resource delete redis-server --force
pcs resource delete vip-redis --force
pcs resource delete ceilometer-central --force
pcs resource delete ceilometer-collector --force
pcs resource delete ceilometer-api --force
pcs resource delete ceilometer-delay --force
pcs resource delete ceilometer-alarm-evaluator --force
pcs resource delete ceilometer-alarm-notifier --force
pcs resource delete ceilometer-notification --force

pcs resource create redis-server redis wait_last_known_master=true --master meta notify=true ordered=true interleave=true
pcs resource create vip-redis IPaddr2 ip=$vip_redis
pcs resource create ceilometer-central systemd:openstack-ceilometer-central --clone interleave=true
pcs resource create ceilometer-collector systemd:openstack-ceilometer-collector --clone interleave=true
pcs resource create ceilometer-api systemd:openstack-ceilometer-api --clone interleave=true
pcs resource create ceilometer-delay Delay startdelay=10 --clone interleave=true
pcs resource create ceilometer-alarm-evaluator systemd:openstack-ceilometer-alarm-evaluator --clone interleave=true
pcs resource create ceilometer-alarm-notifier systemd:openstack-ceilometer-alarm-notifier --clone interleave=true
pcs resource create ceilometer-notification systemd:openstack-ceilometer-notification  --clone interleave=true

pcs constraint order promote redis-server-master then start vip-redis
pcs constraint colocation add vip-redis with master redis-server-master
pcs constraint order start vip-redis then ceilometer-central-clone kind=Optional
pcs constraint order start ceilometer-central-clone then ceilometer-collector-clone
pcs constraint order start ceilometer-collector-clone then ceilometer-api-clone
pcs constraint colocation add ceilometer-api-clone with ceilometer-collector-clone 
pcs constraint order start ceilometer-api-clone then ceilometer-delay-clone
pcs constraint colocation add ceilometer-delay-clone with ceilometer-api-clone
pcs constraint order start ceilometer-delay-clone then ceilometer-alarm-evaluator-clone
pcs constraint colocation add ceilometer-alarm-evaluator-clone with ceilometer-delay-clone
pcs constraint order start ceilometer-alarm-evaluator-clone then ceilometer-alarm-notifier-clone
pcs constraint colocation add ceilometer-alarm-notifier-clone with ceilometer-alarm-evaluator-clone
pcs constraint order start ceilometer-alarm-notifier-clone then ceilometer-notification-clone
pcs constraint colocation add ceilometer-notification-clone with ceilometer-alarm-notifier-clone

pcs constraint order start mongodb-clone then ceilometer-central-clone
pcs constraint order start keystone-clone then ceilometer-central-clone

