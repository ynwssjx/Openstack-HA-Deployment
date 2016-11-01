#!/usr/bin/bash

keystone_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default keystone_secret)
rabbitmq_hosts=$(/usr/bin/bash readini.sh cluster_variables.ini default rabbitmq_hosts)
# public_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
# admin_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
master=$(/usr/bin/bash readini.sh cluster_variables.ini default master)
memcaches=$(/usr/bin/bash readini.sh cluster_variables.ini default memcaches)
share_dir=$(/usr/bin/bash readini.sh cluster_variables.ini default share_dir)
hacluster_passwd=$(/usr/bin/bash readini.sh cluster_variables.ini default hacluster_passwd)
int_ip_set=$(/usr/bin/bash readini.sh cluster_variables.ini computer inter_ip_set)
ext_ip_set=$(/usr/bin/bash readini.sh cluster_variables.ini computer ext_ip_set)
metadata_shared_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default neutron_metadata_shared_secret)
ceilometer_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default ceilometer_secret)
mongodb=$(/usr/bin/bash readini.sh cluster_variables.ini default mongodb)

node_postfix_num=$(echo `hostname`|cut -b 9-)


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


#your system must be initial by openstack_compute_node_system_prepare.sh
if [ ! -f /etc/openstack-kilo_tag/presystem_compute_node.tag ]
	then
	echo "your system do noe be prepared !"
	exit 
fi


yum install -y openstack-nova-compute openstack-utils python-cinder openstack-neutron-openvswitch openstack-ceilometer-compute python-memcached openstack-neutron

# we will use this one as instance shared storage
if [ ! -d $share_dir/instances ]
	then
	mkdir -p $share_dir/instances
    chown nova:nova $share_dir/instances
fi

systemctl disable firewalld
systemctl stop firewalld
 
systemctl enable pcsd
systemctl start pcsd
 
echo $hacluster_passwd | passwd --stdin hacluster

systemctl enable openvswitch
systemctl start openvswitch

ovs-vsctl add-br br-int

systemctl stop libvirtd
systemctl disable libvirtd

# NOTE: vmnet is the interface connected to the internal network.
openstack-config --set /etc/nova/nova.conf DEFAULT  vnc_enabled  True 
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(echo $int_ip_set|cut -d ";" -f $node_postfix_num)
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
# NOTE: same consideration as nova configuration applies here. They need to match.
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$vip_nova:6080/vnc_auto.html

openstack-config --set /etc/nova/nova.conf database connection mysql://nova:nova@$vip_db/nova
openstack-config --set /etc/nova/nova.conf database max_retries -1

openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT  verbose  True
openstack-config --set /etc/nova/nova.conf DEFAULT  debug  True

openstack-config --set /etc/nova/nova.conf DEFAULT memcache_servers  $memcaches
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  openstack


# FIX ME: nova doesn't like hostnames anymore?
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host $vip_nova
# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host ${PHD_VAR_network_internal}.210

openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8775
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $metadata_shared_secret

openstack-config --set /etc/nova/nova.conf glance host $vip_glance

openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf neutron url http://$vip_neutron:9696/
openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name services
openstack-config --set /etc/nova/nova.conf neutron admin_username neutron
openstack-config --set /etc/nova/nova.conf neutron admin_password neutron
openstack-config --set /etc/nova/nova.conf neutron admin_auth_url http://$vip_keystone:35357/v2.0

openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_vif_driver nova.virt.libvirt.vif.LibvirtGenericVIFDriver
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron

openstack-config --set /etc/nova/nova.conf conductor use_local false

# REQUIRED FOR A/A scheduler
openstack-config --set /etc/nova/nova.conf DEFAULT scheduler_host_subset_size 30

openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_host $vip_keystone
openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_tenant_name services
openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_user nova
openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_password nova

openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$vip_keystone:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken identity_uri http://$vip_keystone:5000

openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  openstack

openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier

# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent tunnel_types  vxlan
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent tunnel_types  gre
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent vxlan_udp_port 4789
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs enable_tunneling True
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tenant_network_type gre 
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs integration_bridge br-int
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_bridge br-tun
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs local_ip $(echo $int_ip_set|cut -d ";" -f $node_postfix_num)
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini securitygroup enable_ipset  True
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent l2_population False

# [ -f  /etc/neutron/plugins/ml2/ml2_conf.ini_bak ]  ||  cp -a /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_bak
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2 type_drivers  flat,vlan,gre,vxlan 
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2  tenant_network_types  gre
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2  mechanism_drivers  openvswitch
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2_type_gre tunnel_id_ranges  1:1000
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group  True
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip  ${TUNNEL_IP}
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types  gre

openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit True
openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
openstack-config --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier
# sed -i -e 's#nova.openstack.common.notifier.rpc_notifier#nova.openstack.common.notifier.rpc_notifier\nnotification_driver = ceilometer.compute.nova_notifier#g' /etc/nova/nova.conf

openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host $vip_keystone
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password ceilometer

openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT memcache_servers $memcaches
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_password  openstack

openstack-config --set /etc/ceilometer/ceilometer.conf publisher telemetry_secret $ceilometer_secret

openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://$vip_keystone:5000
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_password ceilometer

openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://$mongodb:27017/ceilometer?replicaSet=ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf database connection max_retries -1

# keep last 5 days data only (value is in secs)
openstack-config --set  /etc/ceilometer/ceilometer.conf database metering_time_to_live 432000


#fix startup bug
rm -rf /etc/neutron/plugin.ini &&  ln -s /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugin.ini
rm -rf  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig  && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service


echo -e "\033[41;37m your system have already been configured as compute node successful! \033[0m"
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/compute_node_install_nova.tag
