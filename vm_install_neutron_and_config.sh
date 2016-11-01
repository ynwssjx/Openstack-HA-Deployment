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



echo "begin install neutron-server"
# if [ -d /etc/neutron ]
# 	then
# 	mv /etc/neutron /etc/neutron.bak
# fi

pcs resource delete neutron-server-api --force
pcs resource delete neutron-scale --force
pcs resource delete neutron-ovs-cleanup --force
pcs resource delete neutron-netns-cleanup --force
pcs resource delete neutron-openvswitch-agent --force
pcs resource delete neutron-dhcp-agent --force
pcs resource delete neutron-l3-agent --force
pcs resource delete neutron-metadata-agent --force
yum clean all && yum makecache
ps -ef |grep neutron|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-neutron|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-neutron
rpm -ql openstack-neutron-ml2|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-neutron-ml2
rpm -ql openstack-neutron-openvswitch|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-neutron-openvswitch


# yum erase -y openstack-neutron openstack-neutron-openvswitch openstack-neutron-ml2 python-neutronclient  which  
yum install -y openstack-neutron openstack-neutron-openvswitch openstack-neutron-ml2 python-neutronclient python-openstackclient which  
#check neutron database
mysql -uroot -proot -e "SHOW DATABASES;"|grep neutron
if [ $? -eq 0 ]
	then
	mysql -uroot -proot -e "DROP DATABASE neutron;"
	mysql -uroot -proot -e "CREATE DATABASE neutron;"
	mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'neutron';"
	mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutron';"
elif [ $? -ne 0 ]
	then
	mysql -uroot -proot -e "CREATE DATABASE neutron;"
	mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'NEUTRON_DBPASS';"
	mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS';" 
fi



cp /etc/neutron/neutron.conf  /etc/neutron/neutron.conf.bak

openstack-config --set  /etc/neutron/neutron.conf DEFAULT bind_host $public_bind_host_ip
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT nova_url http://$vip_nova:8774/v2
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT debug  True

openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier
openstack-config --set /etc/neutron/neutron.conf DEFAULT router_scheduler_driver neutron.scheduler.l3_agent_scheduler.ChanceScheduler


openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_plugin  password 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_id  default 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_id  default 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  services 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  neutron
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url http://$vip_keystone:35357
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$vip_keystone:5000
# openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 
# openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 

openstack-config --set /etc/neutron/neutron.conf database connection  mysql://neutron:neutron@$vip_db:3306/neutron
openstack-config --set /etc/neutron/neutron.conf database max_retries -1

openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  openstack

openstack-config --set /etc/neutron/neutron.conf nova auth_url http://$vip_keystone:35357/
openstack-config --set /etc/neutron/neutron.conf nova auth_plugin password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova region_name regionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name services
openstack-config --set /etc/neutron/neutron.conf nova username nova
openstack-config --set /etc/neutron/neutron.conf nova password nova




cp -a  /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.bak
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,gre,vxlan 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  gre 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  openvswitch 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges  1:1000 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group  True 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks  external
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings external:br-ex 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip $public_bind_host_ip
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types  gre
# is this still required?
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 
# openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver True

rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
if [ $? -eq 0 ]
	then
	echo "neutron-db-manage is successful!"
else
	echo "neutron-db-manage is failed!"
	exit
fi

# There are a number of different approaches to make neutron highly
# available, we cover only A/A and A/P here but more details
# (internal-only) are available in Bugzilla:
#    https://bugzilla.redhat.com/show_bug.cgi?id=1170113#c18
# 
# 1) Fully neutron A/A, considering nodes A,B,C
# 
# all nodes would have l3_ha=True , max_l3_agents_per_router=3, min=2
# A: host=neutron-n-0  B: host=neutron-n-1  C: host=neutron-n-2
# 
# (this way we cover the upgrade path from OSP5->OSP6, by keeping at least one host withb the old neutron-n-0 ID)
# 
# 3) A/P, with 1 active node
# 
# all nodes would have l3_ha=False
# 
# a) A + B + C have host=neutron-n-0
# b) like case 2, but: 
#     A: host=neutron-n-0  B: (passive not set)  C: (passive, not set)
#    and neutron scale does the host= change during failover.

# A/P does NOT require extra settings. Defaults are fine
# Fully A/A requires extra neutron-server configuration:

openstack-config --set /etc/neutron/neutron.conf DEFAULT l3_ha True
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_automatic_l3agent_failover True
openstack-config --set /etc/neutron/neutron.conf DEFAULT max_l3_agents_per_router 3
openstack-config --set /etc/neutron/neutron.conf DEFAULT min_l3_agents_per_router 2

# This value _MUST_ follow the number of nodes in the pacemaker cluster
openstack-config --set /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 3

echo "begin install neutron-agent "
yum install -y openstack-neutron openstack-neutron-openvswitch openvswitch

systemctl enable openvswitch
systemctl start openvswitch

ovs-vsctl del-br br-int
ovs-vsctl del-br br-ex
ovs-vsctl del-br br-tun

ovs-vsctl add-br br-int
ovs-vsctl add-br br-ex

# NOTE: this is the ethernet connected to the external LAN of the controller nodes!
ovs-vsctl add-port br-ex $ext_br_nic
ethtool -K $ext_br_nic gro off

# workaround for keepalived DNS resolution issue within the 
# ha-routers at config reload
# dig A $(hostname) | grep -A1 "ANSWER SEC" | tail -n 1 | awk '{print $NF " " $1}' | sed -e 's/.$//g'  >>/etc/hosts
# grep -q $(hostname) /etc/hosts || echo "Failure to setup hostname entry"

# openvswitch plugin (used as mechanism within ml2)
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent tunnel_types  vxlan
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent vxlan_udp_port 4789
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs local_ip  $public_bind_host_ip
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs enable_tunneling True
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs integration_bridge br-int
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_bridge br-tun
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs bridge_mappings physnet1:br-ex
# openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver  

# ovs l2 population
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent l2_population False

# metadata agent
cp -a  /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_bak
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_uri  http://$vip_keystone:5000
# openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$vip_keystone:35357/v2.0/ #this setting will cause auth error
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$vip_keystone:35357
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_host $vip_keystone
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region regionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name services
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT project_domain_id  default 
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT user_domain_id  default 
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $vip_nova
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_port 8775
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $metadata_shared_secret
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_workers 4
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_backlog 2048
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT verbose  True
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT debug  True



# dhcp agent
cp -a /etc/neutron/dhcp_agent.ini  /etc/neutron/dhcp_agent.ini_bak  
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces False
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq    
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file  /etc/neutron/dnsmasq-neutron.conf
echo "dhcp-option-force=26,1454" >/etc/neutron/dnsmasq-neutron.conf
pkill dnsmasq

# current deployment has a routing problem via qrouter->192.168.16.1 which is the 
# system default nameserver, probably the qrouter has no leg on that net, so... to 
# make that work specify a comma separated
# list of DNS servers to be available (Forwarded to the instances)
# openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_dns_servers  10.35.255.14

# L3 agent
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT handle_internal_only_routers True
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT send_arp_for_ha 3
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces False
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex 
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT verbose   True
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT debug   True

rm -rf  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig  && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service


#/etc/sysctl.conf
sed -e '/^net.bridge/d' -e '/^net.ipv4.conf/d' -i /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >>/etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables=1" >>/etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >>/etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >>/etc/sysctl.conf
sysctl -p >>/dev/null

#wether there is openstack user in rabbitmq cluster
rabbitmqctl list_users|grep openstack
if [ $? -ne 0 ]
	then
	echo "we will add openstack rabibtmq user"
	rabbitmqctl add_user openstack openstack
	rabbitmqctl set_permissions openstack ".*" ".*" ".*"
	rabbitmqctl set_policy ha-all "^" '{"ha-mode":"all"}'
else
	echo "openstack user already exist in rabbitmq cluster"
fi

