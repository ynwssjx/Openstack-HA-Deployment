#!/usr/bin/bash

section=`hostname`
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
keystone_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default keystone_secret)
rabbitmq_hosts=$(/usr/bin/bash readini.sh cluster_variables.ini default rabbitmq_hosts)
public_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
admin_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
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


pcs resource delete glance-fs --force
pcs resource delete glance-api --force
pcs resource delete glance-registry --force
ps -ef |grep glance|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-glance|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-glance

yum install -y openstack-glance openstack-utils python-openstackclient

# Configure the API service

openstack-config --set /etc/glance/glance-api.conf database connection mysql://glance:glance@$vip_db/glance
openstack-config --set /etc/glance/glance-api.conf database max_retries -1

openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone

openstack-config --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://$vip_keystone:35357/
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$vip_keystone:5000/
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password glance
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_plugin  password 
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_domain_id  default 
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken user_domain_id  default 
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_name  services

openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver messaging
# openstack-config --set  /etc/glance/glance-registry.conf DEFAULT notification_driver  noop 
openstack-config --set  /etc/glance/glance-registry.conf DEFAULT verbose  True 
openstack-config --set  /etc/glance/glance-registry.conf DEFAULT debug  True 

openstack-config --set  /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set  /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_password  openstack 
openstack-config --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/glance/glance-api.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60

openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_host $vip_glance
openstack-config --set /etc/glance/glance-api.conf DEFAULT bind_host $public_bind_host_ip

# Configure the registry service

openstack-config --set /etc/glance/glance-registry.conf database connection mysql://glance:glance@$vip_db/glance
openstack-config --set /etc/glance/glance-registry.conf database max_retries -1

openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri http://$vip_keystone:35357/
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$vip_keystone:5000/
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password glance
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_plugin  password 
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_domain_id  default 
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken user_domain_id  default 
# openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_name  services


openstack-config --set /etc/glance/glance-registry.conf DEFAULT notification_driver messaging
# openstack-config --set  /etc/glance/glance-registry.conf DEFAULT notification_driver  noop 
openstack-config --set  /etc/glance/glance-registry.conf DEFAULT verbose  True 
openstack-config --set  /etc/glance/glance-registry.conf DEFAULT debug  True 

openstack-config --set  /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set  /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_password  openstack 
openstack-config --set /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/glance/glance-registry.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60

openstack-config --set /etc/glance/glance-registry.conf DEFAULT registry_host $vip_glance
openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_host $public_bind_host_ip

# create the NFS share mountpoint on the nfs server
if [ ! -d /data/glance ]
	then
	mkdir -p /data/glance
else
	echo "the /data/glance dirctory already exist"
fi




