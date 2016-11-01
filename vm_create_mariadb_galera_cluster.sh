#!/usr/bin/bash



ha_node1=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
ha_node2=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
ha_node3=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)
# node_list must be of the form node1,node2,node3
#
# node names must be in the form that the cluster knows them as
# (ie. no domains) and there can't be a trailing comma (hence the
# extra weird sed command)
node_list="$ha_node1,$ha_node2,$ha_node3"
# node_list=$(echo $PHD_ENV_nodes | sed -e s/.vmnet.${PHD_VAR_network_domain}\ /,/g -e s/.vmnet.${PHD_VAR_network_domain}//)

pcs resource delete galera --force
pcs resource create galera galera enable_creation=true wsrep_cluster_address="gcomm://${node_list}" additional_parameters='--open-files-limit=16384' meta master-max=3 ordered=true op promote timeout=300s on-fail=block --master


# Now we can re-enable the proxy
pcs resource enable lb-haproxy
pcs constraint order start lb-haproxy-clone then start galera-master

# wait for galera to start and become promoted
loop=0; while ! clustercheck > /dev/null 2>&1 && [ "$loop" -lt 60 ]; do
	echo waiting galera to be promoted
	loop=$((loop + 1))
	sleep 5
done


# this one can fail depending on who bootstrapped the cluster
# for node in $ha_node1 $ha_node2 $ha_node3; do
# 	mysql -e "DROP USER ''@'${node}';" || true
# 	mysql -e "DROP USER 'root'@'${node}';" || true
# done

galera_script=galera.setup
echo "" > $galera_script

# echo "mysql -uroot -proot" >>$galera_script
echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED by 'root' WITH GRANT OPTION;" >> $galera_script

for db in keystone glance cinder neutron nova heat; do
    cat<<EOF >> $galera_script
CREATE DATABASE ${db};
GRANT ALL ON ${db}.* TO '${db}'@'%' IDENTIFIED BY '${db}';
EOF
done

echo "FLUSH PRIVILEGES;" >> $galera_script
#echo "quit" >> $galera_script

if [ "$loop" -ge 60 ]; then
	echo Timeout waiting for galera
else
	mysql mysql < $galera_script
	mysqladmin flush-hosts
fi

mysql_secure_installation <<EOF

y
root
root
y
n
y
y
EOF

# mysql -uroot -proot -e "DROP DATABASE keystone;DROP DATABASE glance;DROP DATABASE cinder;DROP DATABASE neutron;DROP DATABASE nova;DROP DATABASE heat;"
 #    mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED by 'root' WITH GRANT OPTION;"
 #    mysql -uroot -proot -e "CREATE DATABASE keystone;"
 #    mysql -uroot -proot -e "GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystone';"
 #    mysql -uroot -proot -e "CREATE DATABASE glance;"
 #    mysql -uroot -proot -e "GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY 'glance';"
 #    mysql -uroot -proot -e "CREATE DATABASE cinder;"
 #    mysql -uroot -proot -e "GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'cinder';"
 #    mysql -uroot -proot -e "CREATE DATABASE neutron;"
 #    mysql -uroot -proot -e "GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutron';"
 #    mysql -uroot -proot -e "CREATE DATABASE nova;"
 #    mysql -uroot -proot -e "GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY 'nova';"
 #    mysql -uroot -proot -e "CREATE DATABASE heat;"
 #    mysql -uroot -proot -e "GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY 'heat';"
 #    mysql -uroot -proot -e "FLUSH PRIVILEGES;"
# mysql -uroot -proot -e "FLUSH—HOSTS"
# pcs resource cleanup
# sleep 10
pcs status
