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


pcs resource delete horizon --force 
ps -ef |grep httpd|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql openstack-dashboard|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y openstack-dashboard

yum install -y mod_wsgi httpd mod_ssl openstack-dashboard memcached pythonmemcached

# NOTE this is a rather scary sed and replace operation to configure horizon
#             in one shot, scriptable way.
#             Keypoints:
#             set ALLOWED_HOSTS to access the web service.
#                   BE AWARE that this command will allow access from everywhere!
#             connection CACHES to memcacehed
#             connect with keystone for authentication
#             fix a LOCAL_PATH to point to the correct location.

horizonememcachenodes=$(echo $memcaches | sed -e "s#,#', '#g" -e "s#^#[ '#g" -e "s#\$#', ]#g")
[ -f /etc/openstack-dashboard/local_settings.bak ] || cp /etc/openstack-dashboard/local_settings  /etc/openstack-dashboard/local_settings.bak
sed -i \
	-e "s#ALLOWED_HOSTS.*#ALLOWED_HOSTS = ['*',]#g" \
	-e "s#^CACHES#SESSION_ENGINE =   'django.contrib.sessions.backends.cache'\nCACHES#g#" \
	-e "s#locmem.LocMemCache'#memcached.MemcachedCache',\n\t'LOCATION' : $horizonememcachenodes#g" \
	-e 's#OPENSTACK_HOST =.*#OPENSTACK_HOST = "'$vip_keystone'"#g' \
	-e "s#^LOCAL_PATH.*#LOCAL_PATH = '/var/lib/openstack-dashboard'#g" \
	-e "s#SECRET_KEY.*#SECRET_KEY = '$horizon_secret'#g#" \
	/etc/openstack-dashboard/local_settings

# workaround buggy packages
echo "COMPRESS_OFFLINE = True" >> /etc/openstack-dashboard/local_settings 
python /usr/share/openstack-dashboard/manage.py compress

# NOTE: fix apache config to listen only on a given interface (internal)
sed  -i -e "s/^Listen.*/Listen $public_bind_host_ip:80/g"  /etc/httpd/conf/httpd.conf 

# NOTE: enable server-status. this is required by pacemaker to verify apache is 
#              responding. Only allow from localhost.
cat > /etc/httpd/conf.d/server-status.conf << EOF
<Location /server-status>
    SetHandler server-status
    Order deny,allow
    Deny from all
    Allow from localhost
</Location>
EOF

echo "your apache httpd server is running!" > /var/www/html/index.html
