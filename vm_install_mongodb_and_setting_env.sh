#!/usr/bin/bash

section=`hostname`
bind_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
master_vm_name=$(/usr/bin/bash readini.sh cluster_variables.ini default master)-vm
master_vm_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $master_vm_name int_ip)

#remove mongodb force
pcs resource delete mongodb --force
ps -ef |grep mongo|grep -v grep|awk '{print "kill -9",$2}'|sh
rpm -ql mongodb-server|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y mongodb-server
rpm -ql mongodb|awk '{printf("rm -rf %s\n",$1)}'|sh && yum erase -y mongodb


yum -y install mongodb mongodb-server

# set binding IP address and replica set
# also use smallfiles = true to stall installation while allocating N GB of journals
sed -i -e '/^bind_ip/d' -e '/^replSet/d' -e '/^smallfiles/d' /etc/mongodb.conf
echo "bind_ip = 0.0.0.0" >> /etc/mongodb.conf
echo "replSet = ceilometer" >> /etc/mongodb.conf
echo "smallfiles = true" >> /etc/mongodb.conf
# sed -i \
# 	-e 's#.*bind_ip.*#bind_ip = 0.0.0.0#g' \
# 	-e 's/.*replSet.*/replSet = ceilometer/g' \
# 	-e 's/.*smallfiles.*/smallfiles = true/g' \
# 	/etc/mongodb.conf

# required to bootstrap mongodb
systemctl start mongod
systemctl stop mongod

