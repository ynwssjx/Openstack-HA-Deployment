#!/usr/bin/bash

section=`hostname`
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
keystone_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default keystone_secret)
horizon_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default horizon_secret)
rabbitmq_hosts=$(/usr/bin/bash readini.sh cluster_variables.ini default rabbitmq_hosts)
public_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
admin_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
master=$(/usr/bin/bash readini.sh cluster_variables.ini default master)
memcaches=$(/usr/bin/bash readini.sh cluster_variables.ini default memcaches)
nfs_dir=$(/usr/bin/bash readini.sh cluster_variables.ini default share_dir)
ext_br_nic=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_br_nic)
metadata_shared_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default neutron_metadata_shared_secret)
mongodb=$(/usr/bin/bash readini.sh cluster_variables.ini default mongodb)
ceilometer_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default ceilometer_secret)

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
ps -ef |grep ceilometer|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-ceilometer-api|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-ceilometer-api
rpm -ql openstack-ceilometer-central|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-ceilometer-central
rpm -ql openstack-ceilometer-collector|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-ceilometer-collector
rpm -ql openstack-ceilometer-common|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-ceilometer-common
rpm -ql openstack-ceilometer-alarm|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-ceilometer-alarm
rpm -ql redis|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y redis


yum install -y redis openstack-ceilometer-api openstack-ceilometer-central openstack-ceilometer-collector openstack-ceilometer-common openstack-ceilometer-alarm python-ceilometer python-ceilometerclient 
# have redis listen on all IPs
sed -i "s/\s*bind \(.*\)$/#bind \1/" /etc/redis.conf

openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host $vip_keystone
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password ceilometer

openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT memcache_servers  $memcaches
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_password  openstack 


openstack-config --set /etc/ceilometer/ceilometer.conf coordination backend_url 'redis://'$vip_redis':6379'

openstack-config --set /etc/ceilometer/ceilometer.conf publisher telemetry_secret $ceilometer_secret

openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://$vip_keystone:5000
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_password ceilometer

openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://$mongodb:27017/ceilometer?replicaSet=ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf database max_retries -1

# keep last 5 days data only (value is in secs). Don't set to retain all data indefinetely.
openstack-config --set  /etc/ceilometer/ceilometer.conf database metering_time_to_live 432000

openstack-config --set  /etc/ceilometer/ceilometer.conf api host $public_bind_host_ip


# mongo --host controller1-vm:27017 --eval 'db = db.getSiblingDB("ceilometer");db.createUser({user: "ceilometer",pwd: "CEILOMETER_DBPASS",roles: [ "readWrite", "dbAdmin" ]})'
