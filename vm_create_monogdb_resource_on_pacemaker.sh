#!/usr/bin/bash



ha_node1=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
ha_node2=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
ha_node3=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)


pcs resource delete mongodb --force
pcs resource create mongodb systemd:mongod op start timeout=300s --clone

# Setup replica (need to wait for mongodb to settle down first!)
sleep 20

# Careful with the node names here, must match FQDN
rm -f /root/mongo_replica_setup.js
cat > /root/mongo_replica_setup.js << EOF
rs.initiate()
sleep(10000)
EOF

for node in $ha_node1 $ha_node2 $ha_node3; do
cat >> /root/mongo_replica_setup.js << EOF
    rs.add("$node");
EOF
done

mongo /root/mongo_replica_setup.js
rm -f /root/mongo_replica_setup.js

echo " rs.status()" > mongotest.js
loop=0; while ! mongo  mongotest.js> /dev/null 2>&1 && [ "$loop" -lt 60 ]; do
	echo waiting mongo to be startup
	loop=$((loop + 1))
	sleep 5
done
