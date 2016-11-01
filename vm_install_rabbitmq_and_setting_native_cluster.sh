#!/usr/bin/bash

section=`hostname`
bind_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
master_vm_name=$(/usr/bin/bash readini.sh cluster_variables.ini default master)-vm
master_vm_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $master_vm_name int_ip)


#we delete rabbitmq-server-master and kill any rabbitmq process and uninstall it compeletely!
pcs resource delete rabbitmq-cluster --force
service rabbitmq-server stop && ps -ef |grep rabbit|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql rabbitmq-server|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y rabbitmq-server


yum install -y rabbitmq-server

# NOTE: we need to bind the service to the internal IP address

cat > /etc/rabbitmq/rabbitmq-env.conf << EOF
NODE_IP_ADDRESS=$bind_ip
EOF

# required to generate the cookies at one node and copy it to other nodes
# if [ "$section" == "$master_vm_name" ]
# 	then
# 	systemctl start rabbitmq-server
#     systemctl stop rabbitmq-server
# else
# 	echo "this node donot generate cookie,so we donot start MQ manually"
# 	systemctl stop rabbitmq-server
# fi
mkdir -p  /var/lib/rabbitmq
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

#if install rabbitmq-server-3.6 and use rabbitmq-server-ha resource agent,pacemaker cluster will call /usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh when cluster resurce start up,
#rabbitmq-server-3.6 will gernerate set_rabbitmq_policy.sh.example ,no set_rabbitmq_policy.sh
cp /usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh.example /usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh
chmod 755 /usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh
sed -i '/^\${OCF_RESKEY_ctl}/d' /usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh
# echo '${OCF_RESKEY_ctl} set_policy ha-all "." '{"ha-mode":"all", "ha-sync-mode":"automatic"}' --apply-to all --priority 0' >>/usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh
echo '${OCF_RESKEY_ctl} set_policy ha-all "." '\''{"ha-mode":"all", "ha-sync-mode":"automatic"}'\'' --apply-to all --priority 0' >>/usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh
echo '${OCF_RESKEY_ctl} add_user openstack openstack' >>/usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh
echo '${OCF_RESKEY_ctl} set_permissions openstack ".*" ".*" ".*" ' >>/usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh


