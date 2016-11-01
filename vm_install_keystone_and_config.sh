#!/usr/bin/bash

section=`hostname`
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
keystone_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default keystone_secret)
rabbitmq_hosts=$(/usr/bin/bash readini.sh cluster_variables.ini default rabbitmq_hosts)
public_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
admin_bind_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)




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


pcs resource delete keystone --force
ps -ef |grep keystone|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-keystone|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-keystone


yum install -y openstack-keystone openstack-utils python-openstackclient python-keystoneclient

openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $keystone_secret

openstack-config --set /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/keystone/keystone.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_password  openstack 


# Define the API endpoints. Be careful with replacing vip-keystone and shell escapes.
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_endpoint http://$vip_keystone:35357/
openstack-config --set /etc/keystone/keystone.conf DEFAULT public_endpoint http://$vip_keystone:5000/
openstack-config --set /etc/keystone/keystone.conf DEFAULT verbose True
openstack-config --set /etc/keystone/keystone.conf DEFAULT debug True
# Configure access to galera. Note that several entries in here are dependent on
# what has been configured before. 'keystone' user, 'keystone' password, vip-db.

openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:keystone@$vip_db/keystone

# Mare sure to retry connection to the DB if the DB is not available immediately at service startup.
openstack-config --set /etc/keystone/keystone.conf database max_retries -1

# Make sure the API service is listening on the internal IP addresses only.
# Once again those shell expansions only work for my specific environment.

# phase3: those are obsoleted by mod_wsgi and apache
openstack-config --set /etc/keystone/keystone.conf eventlet_server public_bind_host $public_bind_host_ip
openstack-config --set /etc/keystone/keystone.conf eventlet_server admin_bind_host $admin_bind_host_ip

# workaround for buggy packaging (ayoung is informed)
openstack-config --set /etc/keystone/keystone.conf token driver keystone.token.persistence.backends.sql.Token

openstack-config --set /etc/keystone/keystone.conf token provider  keystone.token.providers.uuid.Provider 
openstack-config --set /etc/keystone/keystone.conf revoke driver  keystone.contrib.revoke.backends.sql.Revoke


# if [ ! -e /root/keystone_ssl.tar ]; then
#     keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
#     cd /etc/keystone/ssl
#     tar cvp -f /root/keystone_ssl.tar *
# fi

mkdir -p /etc/keystone/ssl
# cd /etc/keystone/ssl
# tar xvp -f ${PHD_VAR_osp_configdir}/keystone_ssl.tar
chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl/