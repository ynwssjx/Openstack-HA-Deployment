#!/usr/bin/bash



ha_node1=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
ha_node2=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
ha_node3=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)
erlang_cookie=$(/usr/bin/bash readini.sh cluster_variables.ini default erlang_cookie)
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq
# scp /var/lib/rabbitmq/.erlang.cookie $ha_node2:/var/lib/rabbitmq/
# scp /var/lib/rabbitmq/.erlang.cookie $ha_node3:/var/lib/rabbitmq/

pcs resource delete rabbitmq-server --force
pcs resource delete rabbitmq-cluster --force

#there are two way to create rabbitmq-cluster resource:
#1.user RA:ocf:rabbitmq:rabbitmq-server-ha ,that from rabbitmq.com and you need instann rabbitmq-server-3.6
#we will use this way
pcs resource create rabbitmq-cluster ocf:rabbitmq:rabbitmq-server-ha --master erlang_cookie=DPMDALGUKEOMPTHWPYKC node_port=5672 \
op monitor interval=30 timeout=120 \
op monitor interval=27 role=Master timeout=120 \
op monitor interval=103 role=Slave timeout=120 OCF_CHECK_LEVEL=30 \
op start interval=0 timeout=120 \
op stop interval=0 timeout=120 \
op promote interval=0 timeout=60 \
op demote interval=0 timeout=60 \
op notify interval=0 timeout=60 \
meta notify=true ordered=false interleave=false master-max=1 master-node-max=1

#2.use RA:ocf:heartbeat:rabbitmq-cluster,that from clusterlabs:https://github.com/ClusterLabs/resource-agents/blob/master/heartbeat/rabbitmq-cluster
#and this recommanded by redhat OSP.BTW,the lastest resource-agent rpm include this RA script
# pcs resource create rabbitmq-server rabbitmq-cluster set_policy='HA ^(?!amq\.).* {"ha-mode":"all"}' meta notify=true --clone ordered=true interleave=true

#wait for 5min until rabbitmq-server is stable
loop=0; while ! rabbitmqctl cluster_status > /dev/null 2>&1 && [ "$loop" -lt 60 ]; do
	echo waiting rabitmq-server to be promoted
	loop=$((loop + 1))
	sleep 5
done
# sleep 60
#检查rabbitmq-cluster-master是否自动运行 /usr/lib/ocf/resource.d/rabbitmq/set_rabbitmq_policy.sh初始化MQ集群
rabbitmqctl list_users|grep openstack
if [ $? -ne 0 ]
	then
	rabbitmqctl add_user openstack openstack
	rabbitmqctl set_permissions openstack ".*" ".*" ".*" 

fi

rabbitmqctl list_policies|grep -i "ha-all"
if [ $? -ne 0 ]
	then
	#将队列设置为镜像队列，即队列会被复制到全部节点上，且保持一致
	rabbitmqctl set_policy ha-all "." '{"ha-mode":"all", "ha-sync-mode":"automatic"}' --apply-to all --priority 0
    # rabbitmqctl add_user openstack openstack
    # rabbitmqctl set_permissions openstack ".*" ".*" ".*" 
fi



   
 # rabbitmqctl stop_app
 # rabbitmqctl join_cluster rabbit@$ha_node1
 # rabbitmqctl join_cluster rabbit@$ha_node2
 # rabbitmqctl start_app
 # rabbitmqctl set_policy ha-all '^(?!amq\.).*' '{"ha-mode": "all"}'
 # rabbitmqctl cluster_status

