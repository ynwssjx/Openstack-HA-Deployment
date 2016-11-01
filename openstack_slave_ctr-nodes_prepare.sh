#!/usr/bin/bash

#this scripts called by openstack_master_interact_slave.sh 
#function of this sctipt:
#1.stop selinux,stop firewalld,configure ntp sync
#2.create local yum repo by NFS mount 
#3.configure /etc/fstab and crontab 
#4.create external bridge switch and internal bridge switch
#5.install virtual and cluster software


function log_info ()
{
     DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
     USER_N=`whoami`
     if [ ! -d /var/log/openstack-kilo ] 
         then
     	 mkdir -p /var/log/openstack-kilo
     fi
     echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/presystem_slave_ctr_node.log

}

function log_error ()
{
     DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
     USER_N=`whoami`
     if [ ! -d /var/log/openstack-kilo ] 
         then
     	 mkdir -p /var/log/openstack-kilo
     fi
     echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/presystem_slave_ctr_node.log

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

##############################################function################################################

#stop firewall
function stop_firewall(){
     service firewalld stop 
     fn_log "stop firewall"
     chkconfig firewalld off 
     fn_log "chkconfig firewalld off"
     
     ping -c 4 ${NAMEHOST} 
     fn_log "ping -c 4 ${NAMEHOST} "
}

#install ntp 
function install_ntp () {
     cat /etc/yum.repos.d|grep openstack
     if [ $? != 0 ]
         then
     	 make_openstack_yumrepo ${NFS_SERVER}
     else
     	 log_info "begin install ntp"
     fi
     yum clean all && yum install ntp -y 
     fn_log "yum clean all && yum install ntp -y"
     #modify /etc/ntp.conf 
     if [ -f /etc/ntp.conf  ]
         then 
     	 cp -a /etc/ntp.conf /etc/ntp.conf_bak
     	 #sed -i 's/^restrict\ default\ nomodify\ notrap\ nopeer\ noquery/restrict\ default\ nomodify\ /' /etc/ntp.conf && sed -i "/^# Please\ consider\ joining\ the\ pool/iserver\ ${NAMEHOST}\ iburst  " /etc/ntp.conf
     	 #commont all ntp server dependency external time and set local time to ntp time server
     	 sed -e "s/^server/#server/" -e "s/^fudge/#fudge/" -e '$a server '''${NFS_SERVER}''' prefer'  -i /etc/ntp.conf
     	 echo "SYNC_HWCLOCK=yes" >> /etc/sysconfig/ntpdate
     	 fn_log "config /etc/ntp.conf"
     fi 
     #restart ntp 
     systemctl enable ntpd.service && systemctl start ntpd.service  
     fn_log "systemctl enable ntpd.service && systemctl start ntpd.service"
     sleep 10
     cat /var/spool/cron/root|grep ntpdate
     if [ $? -eq 0 ]
         then 
     	 log_info "contab will be re-set"
     	 sed -i '/ntpdate/d' /var/spool/cron/root
     	 echo "*/10 * * * * /usr/sbin/ntpdate ${NFS_SERVER} 2>&1> /tmp/ntp.log;hwclock -w" >>/var/spool/cron/root	
     else
     	 echo "*/10 * * * * /usr/sbin/ntpdate ${NFS_SERVER} 2>&1> /tmp/ntp.log;hwclock -w" >>/var/spool/cron/root
     fi		
     
     echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_ntp.tag
}

#disabile selinux
function set_selinx () 
{
     cp -a /etc/selinux/config /etc/selinux/config_bak
     sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config
     setenforce 0
     fn_log "sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config"
}

#make local yum repository
function make_openstack_yumrepo () {
     NFS_SERVER=$1
     service nfs start && service rpcbind start
     systemctl enable nfs-server.service
     fn_log "systemctl enable nfs-server.service"
     # if [ -d /data ]
     # 	then
     # 	umount /data
     # 	umount /etc/yum.repos.d
     # 	rm -rf /data
     # else
     	mkdir /data
     # fi
     
     mount ${NFS_SERVER}:/data /data
     mount ${NFS_SERVER}:/etc/yum.repos.d /etc/yum.repos.d
     if [ -d /data/ISO ]
         then
     	 log_info "NFS mount successful!"
     else
     	 log_error "NFS mount failed,please check your nfs service!"
     	 exit
     fi
     cat /etc/fstab |grep -i "data"
     if [ $? -eq 0 ]
         then 
     	 log_info "/etc/fstab will be re-set"
     	 sed -e '/'''${NFS_SERVER}''':\/data/d' -e '/'''${NFS_SERVER}''':\/etc\/yum.repos.d/d' -i /etc/fstab
     	 echo "${NFS_SERVER}:/data /data  nfs  defaults  0 0">> /etc/fstab
     	 echo "${NFS_SERVER}:/etc/yum.repos.d /etc/yum.repos.d  nfs  defaults  0 0">> /etc/fstab
     else
     	 echo "${NFS_SERVER}:/data /data   nfs   defaults  0 0">> /etc/fstab
     	 echo "${NFS_SERVER}:/etc/yum.repos.d /etc/yum.repos.d   nfs   defaults  0 0">> /etc/fstab
     fi
     
     yum clean all &&yum makecache && yum repolist
     
     echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/make_yumrepo.tag
     fn_log "yum repository initial complete successful!"

}

#whether need config your system or not
function If_config_system(){
	INPUT=yes
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
		exit
	elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
	then
		echo "starting `hostname` system config!"
		rm -rf /etc/openstack-kilo_tag/*
	else
		If_config_system
	fi
}

function install-libvirt()
{
	if [ ! -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
		 then
         make_openstack_yumrepo
	fi
	     yum install -y libvirt* qemu* virt-install bridge-utils
	     fn_log "yum install  libvirt！"
	     systemctl enable libvirtd && systemctl start libvirtd.service
	     fn_log "starting libvirtd"
	     lsmod |grep -i kvm
	if [ $? -eq 0 ]
		 then
		 fn_log "load kvm model"
	else
		 modprobe kvm && modprobe kvm_intel
		 fn_log "modprobe kvm"
	fi
	 #删除virbr0，guest不通过virtual network switch以nat方式访问外部，而是通过桥接方式直接桥接到物理网络
	 #http://www.linuxidc.com/Linux/2013-08/88720.htm
	 virsh net-destroy default
     virsh net-undefine default
     systemctl restart libvirtd
 
     echo `date "+%Y-%m-%d %H:%M:%S"` > /etc/openstack-kilo_tag/install_libvirt.tag
}

#将选定的物理网卡配置为网桥
function setting-physical_nic-bridge()
{
	
	 cp /etc/sysconfig/network-scripts/ifcfg-${phy_ext_nic_name} /etc/sysconfig/network-scripts/ifcfg-${phy_ext_nic_name}.bak
	 cp /etc/sysconfig/network-scripts/ifcfg-${phy_int_nic_name} /etc/sysconfig/network-scripts/ifcfg-${phy_int_nic_name}.bak
 
	 echo "BRIDGE=$ext_bridge_name " >> /etc/sysconfig/network-scripts/ifcfg-${phy_ext_nic_name}
	 echo "BRIDGE=$inter_bridge_name" >> /etc/sysconfig/network-scripts/ifcfg-${phy_int_nic_name}
 
	 echo `date "+%Y-%m-%d %H:%M:%S"` > /etc/openstack-kilo_tag/configure_brideg.tag
}


#创建一个外网桥接和一个内网桥接虚拟交换机
function create-bridge()
{
	
#外网桥接	
	cat > /etc/sysconfig/network-scripts/ifcfg-$ext_bridge_name << EOF
TYPE=Bridge
BOOTPROTO=static
IPV4_FAILURE_FATAL=no
DEVICE=$ext_bridge_name
ONBOOT=yes
IPV6INIT=yes
IPADDR=$ext_br0_ip
NETMASK=255.255.255.0
NETWORK=192.168.115.0
GATEWAY=$ext_br0_gateway
DELAY=0
EOF

#内网桥接
    cat > /etc/sysconfig/network-scripts/ifcfg-$inter_bridge_name << EOT
TYPE=Bridge
BOOTPROTO=static
IPV4_FAILURE_FATAL=no
DEVICE=$inter_bridge_name
ONBOOT=yes
IPADDR=$inter_br0_ip
NETMASK=255.255.255.0
NETWORK=192.168.142.0
DELAY=0
EOT

    /etc/init.d/network restart 
    fn_log "config bridge "

    if grep -q ip_forward /etc/sysctl.conf 
    	then
    	sed -i -e 's#ip_forward.*#ip_forward = 1#g' /etc/sysctl.conf
    else
      	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
      	sysctl -p
    fi
     echo "echo 1 > /sys/class/net/$ext_bridge_name/bridge/multicast_querier" >> /etc/rc.d/rc.local
     echo "echo 1 > /sys/class/net/$inter_bridge_name/bridge/multicast_querier" >> /etc/rc.d/rc.local
     chmod +x /etc/rc.d/rc.local
 
     brctl show|grep $ext_bridge_name
     fn_log "create external bridge virtual switch"
     brctl show |grep $inter_bridge_name
     fn_log "create internal bridge virtual switch"
 
     echo `date "+%Y-%m-%d %H:%M:%S"` > /etc/openstack-kilo_tag/create_virtual_switch.tag
}

#安装集群软件
function install-cluster-software()
{
	if [ ! -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
		then
		make_openstack_yumrepo
	fi
	 yum install pacemaker pcs corosync fence* resource* bind-utils tcpdump sos nfs-utils -y
	 fn_log "yum install cluster software "
 
	 echo `date "+%Y-%m-%d %H:%M:%S"` > /etc/openstack-kilo_tag/install_cluster.tag 
 
}
#################################################function define finish#############################################

################################################main code body#######################################################
NAMEHOST=`hostname`
HOSTNAME=`hostname`
NFS_SERVER=$1
section=`hostname`
#if your system has been cofigurated,there is no need config again,we exit this config scripts
if [ -f  /etc/openstack-kilo_tag/presystem_slave_ctr_node.tag ]
     then 
	 echo -e "\033[41;37m your system will re-config by you \033[0m"
	 log_info "your system donot need config because it was configurated."	
	 If_config_system		
fi


#create dir to locate config label
if  [ ! -d /etc/openstack-kilo_tag ]
     then 
	 mkdir -p /etc/openstack-kilo_tag  
fi


#stop selinux
STATUS_SELINUX=`cat /etc/selinux/config | grep ^SELINUX= | awk -F "=" '{print$2}'`
if [  ${STATUS_SELINUX} = enforcing ]
     then 
	 set_selinx
else 
	 log_info "selinux is disabled."
fi

#stop firewalld
service firewalld status|grep -i running
if [ $? -eq 0 ] 
     then
	 stop_firewall
else
	 log_info "firewalled has been stoped"
fi

#make local yum repository
if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
     then
	 log_info "there is no need make yum repository!"
else 
	 make_openstack_yumrepo ${NFS_SERVER}
fi

#set NTP server
if  [ -f /etc/openstack-kilo_tag/install_ntp.tag ]
     then
	 log_info "ntp had installed."
else
	 install_ntp
fi


section=`hostname`
ext_bridge_name=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_br0_name)
inter_bridge_name=$(/usr/bin/bash readini.sh cluster_variables.ini $section inter_br0_name)
ext_br0_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_br0_ip)
ext_br0_gateway=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_br0_gateway)
inter_br0_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section inter_br0_ip)
phy_ext_nic_name=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_br0_physical)
phy_int_nic_name=$(/usr/bin/bash readini.sh cluster_variables.ini $section inter_br0_physical)

#install libvirt
if [ -f /etc/openstack-kilo_tag/install_libvirt.tag ]
	then
	log_info "libvirt already installed !"
else
	install-libvirt
fi

#install cluster software
if [ -f /etc/openstack-kilo_tag/install_cluster.tag ]
	then
	log_info "cluster software already installed"
else
	install-cluster-software
fi

#seting physical nic bridge,if there be bridge,delete it
if [ -f /etc/openstack-kilo_tag/configure_brideg.tag ]
	then
	log_info "physical bridge already have been configured "
else
	brctl show |grep -i $phy_ext_nic_name
	if [ $? -eq 0 ]
		then
		sed -i '/^BRIDGE/d' /etc/sysconfig/network-scripts/ifcfg-${phy_ext_nic_name}
		cp /etc/sysconfig/network-scripts/ifcfg-${ext_bridge_name} /etc/sysconfig/network-scripts/ifcfg-${ext_bridge_name}.bak
		service network restart
		fn_log "restart network"
		ifconfig $ext_bridge_name down
		brctl delbr $ext_bridge_name
	fi

	brctl show |grep -i $phy_int_nic_name
	if [ $? -eq 0 ]
		then
		sed -i '/^BRIDGE/d' /etc/sysconfig/network-scripts/ifcfg-${phy_int_nic_name}
		cp /etc/sysconfig/network-scripts/ifcfg-${inter_bridge_name} /etc/sysconfig/network-scripts/ifcfg-${inter_bridge_name}.bak
		service network restart
		fn_log "restart network"
		ifconfig $inter_bridge_name down
		brctl delbr $inter_bridge_name
	fi
	setting-physical_nic-bridge
fi

#create virtual bridge switch
if [ -f /etc/openstack-kilo_tag/create_virtual_switch.tag ]
	then
	log_info "virtual  switch already have been created "
else
	create-bridge
fi


#finish
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/presystem_slave_ctr_node.tag
echo -e "\033[32m ###################################################### \033[0m"
echo -e "\033[32m ##   slave ctr node system prepare complete successful!#### \033[0m"
echo -e "\033[32m ###################################################### \033[0m"

echo -e "\033[41;37m begin to reboot system to enforce kernel \033[0m"
log_info "begin to reboot system to enforce kernel."
# reboot
