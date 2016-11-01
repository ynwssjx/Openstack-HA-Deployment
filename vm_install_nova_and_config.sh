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
memcaches=$(/usr/bin/bash readini.sh cluster_variables.ini default memcaches)
nfs_dir=$(/usr/bin/bash readini.sh cluster_variables.ini default share_dir)
ext_br_nic=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_br_nic)
metadata_shared_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default neutron_metadata_shared_secret)


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


pcs resource delete nova-consoleauth --force
pcs resource delete nova-novncproxy --force
pcs resource delete nova-api --force
pcs resource delete nova-scheduler --force
pcs resource delete nova-conductor --force
pcs resource delete nova-cert --force
ps -ef |grep nova|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-nova-console|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-nova-console
rpm -ql openstack-nova-cert|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-nova-cert
rpm -ql openstack-nova-novncproxy|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-nova-novncproxy
rpm -ql openstack-nova-api|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-nova-api
rpm -ql openstack-nova-conductor|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-nova-conductor
rpm -ql openstack-nova-scheduler|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-nova-scheduler



yum install -y openstack-nova-console openstack-nova-cert openstack-nova-novncproxy openstack-utils openstack-nova-api openstack-nova-conductor openstack-nova-scheduler python-cinderclient python-memcached python-novaclient

openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack 
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  openstack




# Particularly in the collapsed case, we get a lot of conflicts with the haproxy server
# openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(host $(hostname -s) | awk '{print $4}')
# openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $(ip addr show dev eth1 scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
# openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(ip addr show dev eth1 scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
# openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_host $(ip addr show dev eth1 scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen $(ip addr show dev eth1 scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
# openstack-config --set /etc/nova/nova.conf DEFAULT osapi_compute_listen $(ip addr show dev eth1 scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')

openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $public_bind_host_ip
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $public_bind_host_ip
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $public_bind_host_ip
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_host $public_bind_host_ip
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen $public_bind_host_ip
openstack-config --set /etc/nova/nova.conf DEFAULT osapi_compute_listen $public_bind_host_ip 
# openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$public_bind_host_ip:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$vip_nova:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT memcached_servers $memcaches
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled  True 
# FIX ME: nova doesn't like hostnames anymore?
# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host vip-nova
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host $vip_nova
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8775
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_vif_driver nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend  rabbit 
openstack-config --set /etc/nova/nova.conf DEFAULT verbose  True 
openstack-config --set /etc/nova/nova.conf DEFAULT debug  True


openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $metadata_shared_secret
openstack-config --set /etc/nova/nova.conf glance host $vip_glance
openstack-config --set /etc/nova/nova.conf neutron url http://$vip_neutron:9696/
openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name services
openstack-config --set /etc/nova/nova.conf neutron admin_username neutron
openstack-config --set /etc/nova/nova.conf neutron admin_password neutron
openstack-config --set /etc/nova/nova.conf neutron admin_auth_url http://$vip_keystone:35357/v2.0


# openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://$vip_keystone:5000 
# openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://$vip_keystone:35357 
# openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_plugin  password 
# openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_id  default 
# openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_id  default 
# openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  services 
# openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova 
# openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  nova 

# those entries were workaround for https://bugs.launchpad.net/neutron/+bug/1464178
# that breaks neutron and evacuation
# openstack-config --set /etc/nova/nova.conf DEFAULT notify_api_faults False
# openstack-config --set /etc/nova/nova.conf DEFAULT vif_plugging_is_fatal True
# openstack-config --set /etc/nova/nova.conf DEFAULT vif_plugging_timeout 300

openstack-config --set /etc/nova/nova.conf conductor use_local false

openstack-config --set /etc/nova/nova.conf database connection mysql://nova:nova@$vip_db/nova
openstack-config --set /etc/nova/nova.conf database max_retries -1

# REQUIRED FOR A/A scheduler
openstack-config --set /etc/nova/nova.conf DEFAULT scheduler_host_subset_size 30
openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_host $vip_keystone
openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_tenant_name services
openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_user nova
openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_password nova


