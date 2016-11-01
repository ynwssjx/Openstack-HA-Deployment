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

pcs resource delete cinder-api --force
pcs resource delete cinder-scheduler --force
pcs resource delete cinder-volume --force
ps -ef |grep cinder|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-cinder|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-cinder

yum install -y openstack-cinder openstack-utils python-memcached python-oslo-db python-cinderclient python-oslo-log  MySQL-python python-keystonemiddleware python-openstackclient


# openstack-config --set /etc/cinder/cinder.conf DEFAULT enable_v1_api false
# openstack-config --set /etc/cinder/cinder.conf DEFAULT enable_v2_api true
openstack-config --set /etc/cinder/cinder.conf database connection mysql://cinder:cinder@$vip_db/cinder
openstack-config --set /etc/cinder/cinder.conf database max_retries -1

openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken identity_uri http://$vip_keystone:35357/
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$vip_keystone:5000/
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password cinder

openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver messaging
openstack-config --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT verbose True
openstack-config --set /etc/cinder/cinder.conf DEFAULT debug True
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host $vip_glance

openstack-config --set /etc/cinder/cinder.conf DEFAULT memcache_servers  $memcaches

openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_hosts $rabbitmq_hosts
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_ha_queues true
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit heartbeat_timeout_threshold 60
openstack-config --set  /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set  /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password  openstack

openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lock/cinder 

# rdo${PHD_VAR_osp_major}-cinder isn't the name of a real host or an IP
# Its the name which we should advertise ourselves as and for A/P it should be the same everywhere
# openstack-config --set /etc/cinder/cinder.conf DEFAULT host rdo${PHD_VAR_osp_major}-cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT host openstack-cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT osapi_volume_listen $public_bind_host_ip
openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_shares_config /etc/cinder/nfs_exports
openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_sparsed_volumes true
openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_mount_options v3

openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.nfs.NfsDriver

[ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder && chown cinder:cinder /var/lock/cinder  -R
sed -i '/\/var\/lock\/cinder/d' /etc/rc.d/rc.local
echo " " >>/etc/rc.d/rc.local 
echo "[ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder " >>/etc/rc.d/rc.local 
echo "chown cinder:cinder /var/lock/cinder  -R" >>/etc/rc.d/rc.local 
chmod +x /etc/rc.d/rc.local

# NOTE: this config section is to enable and configure the NFS cinder driver.
# Create the directory on the server
mkdir -p $nfs_dir/cinder

chown -R cinder:cinder $nfs_dir/cinder

cat > /etc/cinder/nfs_exports << EOF
$master:$nfs_dir/cinder
EOF

chown root:cinder /etc/cinder/nfs_exports
chmod 0640 /etc/cinder/nfs_exports



