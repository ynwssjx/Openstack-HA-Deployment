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

pcs resource delete heat-api  --force
pcs resource delete heat-api-cfn --force
pcs resource delete heat-api-cloudwatch  --force
pcs resource delete heat-engine --force
ps -ef |grep heat|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-heat-engine|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-heat-engine
rpm -ql openstack-heat-api|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-heat-api
rpm -ql openstack-heat-api-cfn|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-heat-api-cfn
rpm -ql openstack-heat-api-cloudwatch|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-heat-api-cloudwatch

yum install -y openstack-heat-engine openstack-heat-api openstack-heat-api-cfn openstack-heat-api-cloudwatch python-heatclient openstack-utils python-glanceclient

openstack-config --set /etc/heat/heat.conf database connection mysql://heat:heat@$vip_db/heat
openstack-config --set /etc/heat/heat.conf database database max_retries -1

openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_user heat
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_password heat
openstack-config --set /etc/heat/heat.conf keystone_authtoken service_host $vip_keystone
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_host $vip_keystone
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri http://$vip_keystone:35357
openstack-config --set /etc/heat/heat.conf keystone_authtoken keystone_ec2_uri http://$vip_keystone:35357
openstack-config --set /etc/heat/heat.conf ec2authtoken auth_uri http://$vip_keystone:5000

openstack-config --set /etc/heat/heat.conf DEFAULT memcache_servers   $memcaches
openstack-config --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/heat/heat.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_password  openstack 


openstack-config --set /etc/heat/heat.conf heat_api bind_host $public_bind_host_ip
openstack-config --set /etc/heat/heat.conf heat_api_cfn bind_host $public_bind_host_ip
openstack-config --set /etc/heat/heat.conf heat_api_cloudwatch bind_host $public_bind_host_ip
openstack-config --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url $vip_heat:8000
openstack-config --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url $vip_heat:8000/v1/waitcondition
openstack-config --set /etc/heat/heat.conf DEFAULT heat_watch_server_url $vip_heat:8003

openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend heat.openstack.common.rpc.impl_kombu

openstack-config --set /etc/heat/heat.conf DEFAULT notification_driver heat.openstack.common.notifier.rpc_notifier

# disable CWLiteAlarm that is incompatible with A/A
openstack-config --set /etc/heat/heat.conf DEFAULT enable_cloud_watch_lite false
