#!/usr/bin/bash


section=`hostname`
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
keystone_secret=$(/usr/bin/bash readini.sh cluster_variables.ini default keystone_secret)

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

if [ ! -e /root/keystone_ssl.tar ]; then
    keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
    cd /etc/keystone/ssl
    tar cvp -f /root/keystone_ssl.tar *
    scp /root/keystone_ssl.tar ${ip_node[2]}:/root && ssh root@${ip_node[2]} "cd /etc/keystone/ssl && tar -xvp -f /root/keystone_ssl.tar"
    scp /root/keystone_ssl.tar ${ip_node[3]}:/root && ssh root@${ip_node[3]} "cd /etc/keystone/ssl && tar -xvp -f /root/keystone_ssl.tar"
    cd
fi

mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'keystone';" 
mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystone';"   
su keystone -s /bin/sh -c "keystone-manage -v -d db_sync"

pcs resource delete keystone
pcs resource create keystone systemd:openstack-keystone --clone interleave=true


# In a collapsed environment, we can instruct the cluster to start
# things in a particular order and require services to be active
# on the same hosts.  We do this with constraint
pcs constraint order start lb-haproxy-clone then keystone-clone
pcs constraint order promote galera-master then keystone-clone
pcs constraint order start rabbitmq-cluster-master then keystone-clone
pcs constraint order start memcached-clone then keystone-clone


export OS_TOKEN=$keystone_secret
export OS_URL="http://$vip_keystone:35357/v2.0"
export OS_REGION_NAME=regionOne

while ! openstack service list; do
    echo "Waiting for keystone to be active"
    sleep 1
done

openstack service create \
	--name=keystone \
	--description="Keystone Identity Service" \
	identity

openstack endpoint create \
	--publicurl "http://$vip_keystone:5000/v2.0" \
	--adminurl "http://$vip_keystone:35357/v2.0" \
	--internalurl "http://$vip_keystone:5000/v2.0" \
	--region regionOne \
	keystone

openstack user create --password admin admin
openstack role create admin
openstack project create admin
openstack role add --project admin --user admin admin

# Save admin credential in a file. This will be useful many times over the how-to!

cat >  /root/adminrc << EOF
export OS_USERNAME=admin 
export OS_TENANT_NAME=admin
export OS_PROJECT_NAME=admin
export OS_REGION_NAME=regionOne
export OS_PASSWORD=admin
export OS_AUTH_URL=http://$vip_keystone:35357/v2.0/
export PS1='[\u@\h \W(keystone_admin)]\$ '
EOF

openstack user create --password demo demo
openstack role create _member_
openstack project create demo
openstack role add --project demo --user demo _member_

# Save user credential in a file for testing purposes.

cat >  /root/demorc << EOF
export OS_USERNAME=demo
export OS_TENANT_NAME=demo
export OS_PROJECT_NAME=demo
export OS_REGION_NAME=regionOne
export OS_PASSWORD=demo
export OS_AUTH_URL=http://$vip_keystone:5000/v2.0/
export PS1='[\u@\h \W(keystone_user)]\$ '
EOF

# create service tenant/project
openstack project create --description "Services Tenant" services

# glance
openstack user create --password glance glance
openstack role add --project services --user glance admin
openstack service create --name=glance --description="Glance Image Service" image
openstack endpoint create \
	--publicurl "http://$vip_glance:9292" \
	--adminurl "http://$vip_glance:9292" \
	--internalurl "http://$vip_glance:9292" \
	--region regionOne \
	glance

# cinder
openstack user create --password cinder cinder
openstack role add --project services --user cinder admin
openstack service create --name=cinder --description="Cinder Volume Service" volume
openstack endpoint create \
	--publicurl "http://$vip_cinder:8776/v1/\$(tenant_id)s" \
	--adminurl "http://$vip_cinder:8776/v1/\$(tenant_id)s" \
	--internalurl "http://$vip_cinder:8776/v1/\$(tenant_id)s" \
	--region regionOne \
	cinder

openstack service create --name=cinderv2 --description="OpenStack Block Storage" volumev2
openstack endpoint create \
	--publicurl "http://$vip_cinder:8776/v2/\$(tenant_id)s" \
	--adminurl "http://$vip_cinder:8776/v2/\$(tenant_id)s" \
	--internalurl "http://$vip_cinder:8776/v2/\$(tenant_id)s" \
	--region regionOne \
	cinderv2

# swift
openstack user create --password swift swift
openstack role add --project services --user swift admin
openstack service create --name=swift --description="Swift Storage Service" object-store
openstack endpoint create \
	--publicurl "http://$vip_swift:8080/v1/AUTH_\$(tenant_id)s" \
	--adminurl "http://$vip_swift:8080/v1" \
	--internalurl "http://$vip_swift:8080/v1/AUTH_\$(tenant_id)s" \
	--region regionOne \
	swift

# neutron
openstack user create --password neutron neutron
openstack role add --project services --user neutron admin
openstack service create --name=neutron --description="OpenStack Networking Service" network
openstack endpoint create \
	--publicurl "http://$vip_neutron:9696" \
	--adminurl "http://$vip_neutron:9696" \
	--internalurl "http://$vip_neutron:9696" \
	--region regionOne \
	neutron

# nova
openstack user create --password nova nova
openstack role add --project services --user nova admin
openstack service create --name=compute --description="OpenStack Compute Service" compute
openstack endpoint create \
	--publicurl "http://$vip_nova:8774/v2/\$(tenant_id)s" \
	--adminurl "http://$vip_nova:8774/v2/\$(tenant_id)s" \
	--internalurl "http://$vip_nova:8774/v2/\$(tenant_id)s" \
	--region regionOne \
	compute

# heat
openstack user create --password heat heat
openstack role add --project services --user heat admin
openstack service create --name=heat --description="Heat Orchestration Service" orchestration
openstack endpoint create \
	--publicurl "http://$vip_heat:8004/v1/%(tenant_id)s" \
	--adminurl "http://$vip_heat:8004/v1/%(tenant_id)s" \
	--internalurl "http://$vip_heat:8004/v1/%(tenant_id)s" \
	--region regionOne \
	heat
openstack service create --name=heat-cfn --description="Heat CloudFormation Service" cloudformation
openstack endpoint create \
	--publicurl "http://$vip_heat:8000/v1" \
	--adminurl "http://$vip_heat:8000/v1" \
	--internalurl "http://$vip_heat:8000/v1" \
	--region regionOne \
	heat-cfn

# ceilometer
openstack user create --password ceilometer ceilometer
openstack role add --project services --user ceilometer admin
openstack role create ResellerAdmin
openstack role add --project services --user ceilometer ResellerAdmin
openstack service create --name=ceilometer --description="OpenStack Telemetry Service" metering
openstack endpoint create \
	--publicurl "http://$vip_ceilometer:8777" \
	--adminurl "http://$vip_ceilometer:8777" \
	--internalurl "http://$vip_ceilometer:8777" \
	--region regionOne \
	ceilometer