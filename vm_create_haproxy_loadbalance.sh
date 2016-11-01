#!/usr/bin/bash

# function of this script:
# 1.configure haproxy.cfg
# 2.create VIP resource on pacemaker cluster
# 3.the monitor web GUI is:http://$log_host_ip/haproxy?openstack,username and passwd is admin

# The VIPs lists: 
#components=lb db rabbitmq keystone memcache glance cinder swift-brick swift neutron nova horizon heat mongodb ceilometer qpid
#末尾IP段从components的左到右由200开始以1递增
# db         192.168.142.201
# rabbitmq   192.168.142.202
# qpid       192.168.142.215
# keystone   192.168.142.203
# glance     192.168.142.205
# cinder     192.168.142.206
# swift      192.168.142.208
# neutron    192.168.142.209
# nova       192.168.142.210
# horizon    192.168.142.211
# heat       192.168.142.212
# ceilometer 192.168.142.214



components=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy components)
internal_network=$(/usr/bin/bash readini.sh cluster_variables.ini haproxy internal_network)
hacluster_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
hacluster_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
hacluster_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
ha_cluster_node_num=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_node_num)
section=`hostname`
log_host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)



# HA Proxy defaults
if [ -f /etc/haproxy/haproxy.cfg ]
	then

	cp /etc/haproxy/haproxy.cfg  /etc/haproxy/haproxy.cfg.bak 
	rm -rf /etc/haproxy/haproxy.cfg 
fi


cat > /etc/haproxy/haproxy.cfg << EOF
global
    daemon
    group    haproxy                         
    maxconn  4000
    pidfile  /var/run/haproxy.pid           
    user     haproxy  
    stats    socket /var/lib/haproxy/stats   
    log      $log_host_ip local0
defaults
    mode tcp
    maxconn 10000
    timeout  connect 10s
    timeout  client 1m
    timeout  server 1m
    timeout  check 10s
listen stats                   
    mode          http
    bind          $log_host_ip:8080                       
    stats         enable                     
    stats         hide-version                
    stats uri     /haproxy?openstack          
    stats realm   Haproxy\Statistics           
    stats admin if TRUE 
    stats auth    admin:admin 
    stats refresh 10s

EOF

# Special case front-ends

cat >> /etc/haproxy/haproxy.cfg << EOF
frontend vip-db
    bind ${internal_network}.201:3306
    timeout client 90m
    default_backend db-vms-galera

frontend vip-qpid
    bind ${internal_network}.215:5672
    timeout client 120s
    default_backend qpid-vms

frontend vip-horizon
    bind ${internal_network}.211:80
    timeout client 180s
    cookie SERVERID insert indirect nocache
    default_backend horizon-vms

frontend vip-ceilometer
    bind ${internal_network}.214:8777
    timeout client 90s
    default_backend ceilometer-vms

frontend vip-rabbitmq
    option clitcpka
    bind ${internal_network}.202:5672
    timeout client 900m
    default_backend rabbitmq-vms
EOF

# nova-metadata needs "balance roundrobin" for frontend?
#db-vms-mariadb:58:3306:90s

mappings="
keystone-admin:203:64:35357
keystone-public:203:64:5000
glance-api:205:70:9191
glance-registry:205:70:9292
cinder:206:73:8776
swift:208:79:8080
neutron:209:82:9696
nova-vnc-novncproxy:210:85:6080
nova-vnc-xvpvncproxy:210:85:6081
nova-metadata:210:85:8775
nova-api:210:85:8774
horizon:x:85:80:108s
heat-cfn:212:91:8000
heat-cloudw:212:91:8004
heat-srv:212:91:8004
ceilometer:x:97:8777
"

for mapping in $mappings; do 
    server=$(echo $mapping | awk -F: '{print $1}' | awk -F- '{print $1}')
    service=$(echo $mapping | awk -F: '{print $1}')
    src=$(echo $mapping | awk -F: '{print $2}')
    target=$(echo $mapping | awk -F: '{print $3}')
    port=$(echo $mapping | awk -F: '{print $4}')
    timeout=$(echo $mapping | awk -F: '{print $5}')

    echo "Creating mapping for ${server} ${service}"

    if [ ${src} != x ]; then
	echo "frontend vip-${service}" >> /etc/haproxy/haproxy.cfg
	echo "    bind ${internal_network}.${src}:${port}" >> /etc/haproxy/haproxy.cfg
	echo "    default_backend ${service}-vms" >> /etc/haproxy/haproxy.cfg
    fi

    echo "backend ${service}-vms" >> /etc/haproxy/haproxy.cfg
    echo "    balance roundrobin" >> /etc/haproxy/haproxy.cfg
    if [ ! -z $timeout ]; then
	echo "    timeout server ${timeout}" >> /etc/haproxy/haproxy.cfg
    fi
    for ((i=1;i<=$ha_cluster_node_num;i++)); do
	echo "    server ${hacluster_node[i]} ${ip_node[i]}:${port} check inter 1s" >> /etc/haproxy/haproxy.cfg
    done
done

# Special case back-ends

cat >> /etc/haproxy/haproxy.cfg << EOF
backend qpid-vms
# comment out 'stick-table' and add 'balance roundrobin' for A/A cluster mode in qpid
    stick-table type ip size 2
    stick on dst
    timeout server 120s
    server controller1-vm ${internal_network}.110:5672 check inter 1s
    server controller2-vm ${internal_network}.111:5672 check inter 1s
    server controller3-vm ${internal_network}.112:5672 check inter 1s

backend db-vms-galera
    option httpchk
    option tcpka
    stick-table type ip size 1000
    stick on dst
    timeout server 90m
    server controller1-vm ${internal_network}.110:3306 check inter 1s port 9200 backup on-marked-down shutdown-sessions
    server controller2-vm ${internal_network}.111:3306 check inter 1s port 9200 backup on-marked-down shutdown-sessions
    server controller3-vm ${internal_network}.112:3306 check inter 1s port 9200 backup on-marked-down shutdown-sessions

backend rabbitmq-vms
    option srvtcpka
    balance roundrobin
    timeout server 900m
    server controller1-vm ${internal_network}.110:5672 check inter 1s
    server controller2-vm ${internal_network}.111:5672 check inter 1s
    server controller3-vm ${internal_network}.112:5672 check inter 1s
EOF

scp /etc/haproxy/haproxy.cfg ${hacluster_node[2]}:/etc/haproxy
scp /etc/haproxy/haproxy.cfg ${hacluster_node[3]}:/etc/haproxy
pcs resource delete lb-haproxy
pcs resource create lb-haproxy systemd:haproxy --clone


# In a collapsed environment, we can instruct the cluster to start，things in a particular order and require services to be active
# on the same hosts.  We do this with constraints.
offset=200
for section in ${components}; do
    case $section in 
	lb|memcache|swift-brick|mongodb)
	    echo "No VIP needed for $section"
	    ;;
	*)
        pcs resource delete vip-${section}
	    pcs resource create vip-${section} IPaddr2 ip=${internal_network}.${offset} nic=eth1
	    pcs constraint order start vip-${section} then lb-haproxy-clone kind=Optional
	    pcs constraint colocation add vip-${section} with lb-haproxy-clone
	    ;;
    esac
    offset=$(( $offset + 1 ))
done

pcs cluster stop --all
sleep 5
pcs cluster start --all
sleep 10


