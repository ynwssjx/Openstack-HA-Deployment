#!/usr/bin/bash


password=$(/usr/bin/bash readini.sh cluster_variables.ini default hacluster_passwd)
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
section=`hostname`
bind_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)

#To destroy DB completely,we delete mariadb-galera and kill any process about mysql and remove any dir&file about mariadb rpm
pcs resource delete galera --force
lsof -i:3306 |grep mysql|awk '{print "kill",$2}'|sh
rpm -ql mariadb-galera-server|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y mariadb-galera-server

yum install -y mariadb-galera-server xinetd rsync

# Allowing the proxy to perform health checks on galera while we're initializing it is... problematic. 
echo "disable lb-haproxy before initializing  mariadb-galera"
pcs resource disable lb-haproxy


cat > /etc/sysconfig/clustercheck << EOF
MYSQL_USERNAME="clustercheck"
MYSQL_PASSWORD="$password"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
EOF

# workaround some old buggy mariadb packages
# that created log files as root:root and newer
# packages would fail to start....
chown mysql:mysql /var/log/mariadb -R


systemctl start mysqld.service
if [ $? -ne 0 ]
        then
        echo "start mariadb failed!"
        exit
fi

# required for clustercheck to work
mysql -e "CREATE USER 'clustercheck'@'localhost' IDENTIFIED BY '${password}';"
systemctl stop mysqld.service

# Configure galera cluster
# NOTE: wsrep ssl encryption is strongly recommended and should be enabled
#             on all production deployments. This how-to does NOT display how to 
#             configure ssl. The shell expansion points to the internal IP address of the  
#             node.

cat > /etc/my.cnf.d/galera.cnf << EOF
[mysqld]
skip-name-resolve=1
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
innodb_locks_unsafe_for_binlog=1
query_cache_size=0
query_cache_type=0
bind_address=$bind_ip

wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_name="galera_cluster"
wsrep_slave_threads=1
wsrep_certify_nonPK=1
wsrep_max_ws_rows=131072
wsrep_max_ws_size=1073741824
wsrep_debug=0
wsrep_convert_LOCK_to_trx=0
wsrep_retry_autocommit=1
wsrep_auto_increment_control=1
wsrep_drupal_282555_workaround=0
wsrep_causal_reads=0
wsrep_notify_cmd=
wsrep_sst_method=rsync
EOF

cat > /etc/xinetd.d/galera-monitor << EOF
service galera-monitor
{
        port            = 9200
        disable         = no
        socket_type     = stream
        protocol        = tcp
        wait            = no
        user            = root
        group           = root
        groups          = yes
        server          = /usr/bin/clustercheck
        type            = UNLISTED
        per_source      = UNLIMITED
        log_on_success  = 
        log_on_failure  = HOST
        flags           = REUSE
}
EOF

systemctl enable xinetd
systemctl start xinetd
