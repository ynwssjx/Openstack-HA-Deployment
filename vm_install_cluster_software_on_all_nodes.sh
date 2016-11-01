#!/usr/bin/bash

function log_info ()
#log function
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/install_cluster_software.log.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/install_cluster_software.log

}

function fn_log ()  {
if [  $? -eq 0  ]
then
	log_info "$@ successful."
	echo -e "\033[32m $@ successful. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}

fence_xvm=$(/usr/bin/bash readini.sh cluster_variables.ini default fence_xvm)
ntp_server=$(/usr/bin/bash readini.sh cluster_variables.ini default master)
# hacluster_passwd=$(/usr/bin/bash readini.sh cluster_variables.ini default hacluster_passwd)
# ha_cluster_node_num=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_node_num)
# hacluster_node1=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1)
# hacluster_node2=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2)
# hacluster_node3=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3)
# ha_cluster_name=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_cluster_name)



# install the packages
yum install -y pcs pacemaker corosync fence-agents-all resource-agents

# enable pcsd
systemctl enable pcsd
systemctl start pcsd

systemctl disable firewalld
systemctl stop firewalld

#config ntp

sed -i s/^server.*// /etc/ntp.conf
echo "server $ntp_server iburst" >> /etc/ntp.conf
# echo $PHD_VAR_network_clock > /etc/ntp/step-tickers

#sync_to_hardware clock
echo "SYNC_HWCLOCK=yes" >> /etc/sysconfig/ntpdate

# systemctl enable ntpdate
# systemctl start ntpdate

systemctl enable ntpd
systemctl start ntpd


# Set up the authkey
mkdir -p /etc/cluster
echo ${fence_xvm} > /etc/cluster/fence_xvm.key