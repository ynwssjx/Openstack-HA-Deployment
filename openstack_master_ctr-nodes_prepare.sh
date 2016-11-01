#!/usr/bin/bash

#functions of this scripts :
#1.stop selinux,stop firewalld,configure ntp server
#2.create local yum repo
#3.export nfs to share yum repository
#4.create external bridge switch and internal bridge switch
#5.install virtual and cluster software
#6.seting hostname and build ssh credit controllers each other
#7.call scripts to initial slave controller nodes

#this scripts will require other scripts as follow:
#1.openstack_slave_nodes_stat.sh；
#2.readini.sh;
#3.cluster.variables.ini;
#4.openstack_slave_ctr-nodes_prepare.sh
#5.build-ssh-credit.sh

#this scripts will product files as follow:
#1.nodes_ip_list.txt
#2.lots of flag files with ending *.tag

#log function
function log_info () 
{
     DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
     USER_N=`whoami`
  if [ ! -d /var/log/openstack-kilo ] 
     then
     mkdir -p /var/log/openstack-kilo
  fi
     echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/openstack_ctr-nodes_prepare.log

}

function log_error ()
{
     DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
     USER_N=`whoami`
   if [ ! -d /var/log/openstack-kilo ] 
     then
   	 mkdir -p /var/log/openstack-kilo
   fi
     echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/openstack_ctr-nodes_prepare.log

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

###############################initial master controller node####################################
#set hostname
function set_hostname () {
     hostnamectl set-hostname ${NAMEHOST}
     fn_log "set hostname"
     echo "${host_ip} ${NAMEHOST} " >>/etc/hosts
     fn_log  "modify hosts"
}

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
   if [ ! -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
     then
     make_openstack_yumrepo
   fi
   
     yum clean all && yum install ntp -y 
     fn_log "yum clean all && yum install ntp -y"
     #modify /etc/ntp.conf 
   if [ -f /etc/ntp.conf  ]
     then 
   	 cp -a /etc/ntp.conf /etc/ntp.conf_bak
   	 #sed -i 's/^restrict\ default\ nomodify\ notrap\ nopeer\ noquery/restrict\ default\ nomodify\ /' /etc/ntp.conf && sed -i "/^# Please\ consider\ joining\ the\ pool/iserver\ ${NAMEHOST}\ iburst  " /etc/ntp.conf
   	 #commont all ntp server dependency external time and set local time to ntp time server
   	 sed -e '/^server/d' -e '/^#server/d' -e '/^fudge/d' -e '/^#fudge/d'  -i /etc/ntp.conf
   	 sed -e '$a server 127.127.1.0' -e '$a fudge 127.127.1.0 stratum' -i /etc/ntp.conf
   	 echo "SYNC_HWCLOCK=yes" >> /etc/sysconfig/ntpdate
   	 fn_log "config /etc/ntp.conf"
   fi 
   #restart ntp 
     systemctl enable ntpd.service && systemctl start ntpd.service  
     fn_log "systemctl enable ntpd.service && systemctl start ntpd.service"
     sleep 10
     ntpq -c peers 
     ntpq -c assoc
     echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_ntp.tag
}

#disabile selinux
function set_selinx () 
{
     cp -a /etc/selinux/config /etc/selinux/config_bak
     sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config
     fn_log "sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config"
}

#make local yum repository
function make_openstack_yumrepo () {
     #cd /etc/yum.repos.d && rm -rf CentOS-Base.repo.bk &&  mv CentOS-Base.repo CentOS-Base.repo.bk   && wget http://mirrors.163.com/.help/CentOS7-Base-163.repo  
     #remove all repo dependency external repository and just use local yum repo
     
     rm -rf /etc/yum.repos.d/*
     fn_log "rm -rf  /etc/yum.repos.d/* "
     
     #make ISO packges yum repo
     touch /etc/yum.repos.d/centos7-iso.repo 
     echo "[centos7-iso]" >> /etc/yum.repos.d/centos7-iso.repo
     fn_log "touch /etc/yum.repos.d/centos7-iso.repo && echo \"[centos7-iso]\">> /etc/yum.repos.d/centos7-iso.repo"
     sed -i '$aname=centos7-iso\nbaseurl=file:///data/ISO\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/centos7-iso.repo && yum clean all && yum makecache
     fn_log "sed -i '$aname=centos7-iso\nbaseurl=file:///data/ISO\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/centos7-iso.repo && yum clean all && yum makecache"
     #yum clean all && yum install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm -y
     #make rdo-epel yum repo
     
     rpm -aq|grep createrepo
     if [ $? != 0 ] 
         then
     	 yum install -y createrepo
     fi
     cd /data/rdo-openstack-epel && createrepo --update --baseurl=`pwd` `pwd`
     cd /data/rdo-openstack-kilo/openstack-common && createrepo --update --baseurl=`pwd` `pwd`
     cd /data/rdo-openstack-kilo/openstack-kilo && createrepo --update --baseurl=`pwd` `pwd`
     touch /etc/yum.repos.d/rdo-epel.repo && echo "[rdo-epel]">>/etc/yum.repos.d/rdo-epel.repo
     touch /etc/yum.repos.d/openstack-common.repo && echo "[openstack-common]">>/etc/yum.repos.d/openstack-common.repo
     touch /etc/yum.repos.d/openstack-kilo.repo && echo "[openstack-kilo]">>/etc/yum.repos.d/openstack-kilo.repo
     sed -i '$aname=extra packages enterprise linux\nbaseurl=file:///data/rdo-openstack-epel\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/rdo-epel.repo
     sed -i '$aname=openstack common packages\nbaseurl=file:///data/rdo-openstack-kilo/openstack-common\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/openstack-common.repo
     sed -i '$aname=openstack kilo packages\nbaseurl=file:///data/rdo-openstack-kilo/openstack-kilo\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/openstack-kilo.repo
     
     yum clean all && yum makecache
     fn_log "yum clean all&&yum makecache"
     
     echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/make_yumrepo.tag
     cd $CUR_PATH
     fn_log "yum repository initial complete successful!"
     #yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y
     #fn_log "yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y"
}

#config master controller node NFS 
function nfs-export()
{
     yum clean all && yum install rpcbind nfs-utils -y
     service rpcbind start && service nfs start && systemctl enable nfs-server.service
     cat /etc/exports|grep "/data"
     if [ $? -eq 0 ]
         then
     	 sed -e '/data/d' -e '/yum.repos.d/d' -i /etc/exportsr
     fi
  
     echo "/data *(rw,sync,no_root_squash,no_all_squash)" >> /etc/exports
     echo "/etc/yum.repos.d *(rw,sync,no_root_squash,no_all_squash)" >>/etc/exports
     exportfs -a
     exportfs
     showmount -e
     if [ $? != 0 ]
         then
     	 log_info "controller node NFS export failure!"
     	 echo -e "\033[41;37m controller node NFS export failure! \033[0m" 
     	 exit
     else
     	 echo "NFS export successful!"
     fi
         echo `date "+%Y-%m-%d %H:%M:%S"` > /etc/openstack-kilo_tag/install_nfs.tag
}

#whether need config your system or not
function If_config_system(){
	read -p "you confirm that you want to re-config master ctr node [yes/no]:" INPUT
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	     then
	     echo "we will directly configure slave controlelr nodes!"
		 /usr/bin/bash openstack_slave_nodes_stat.sh
		 exit #不配置master controller，直接去配置slave controler nodes，完成退出！
	elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
	then
		 echo "will re-config system!"
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



#####################################main body#########################
#if your system has been cofigurated,there is no need config again,we exit this config scripts
if [ -f  /etc/openstack-kilo_tag/openstack_ctr-nodes_prepare.tag ]
then 
	 echo -e "\033[41;37m your system donot need config because it was configurated \033[0m"
	 log_info "your system donot need config because it was configurated."	
	 If_config_system		
fi


# read -p "please input hostname for master ctr nodes[default:controller1] :" install_number

master_node_name=$(/usr/bin/bash readini.sh cluster_variables.ini default master)
NAMEHOST=$master_node_name
host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini default ip_master)
CUR_PATH=$PWD

#set hostname
if  [ -z ${master_node_name}  ]
then 
     echo "controller" >$PWD/hostname
     NAMEHOST=controller1
else
	 echo "${master_node_name}" >$PWD/hostname
fi
#create dir to locate config label
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	 mkdir -p /etc/openstack-kilo_tag  
fi

#make local yum repository
if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	 log_info "there is no need make yum repository!"
else 
	 make_openstack_yumrepo
fi


#the first eth nic IP will be as openstack cluster management ip
# read -p "please choose your NIC num as management IP on master ctr node[default 0st NIC]:" NIC_NUM
# if [ -z ${NIC_NUM} ]
# then
# 	 echo "use default the first NIC as your management IP"
# 	 NIC_NUM=1
# fi
# NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 2`: |awk -F ":" '{print$2}')
# NIC_IP=$(ifconfig ${NIC_NAME}  | grep netmask | awk -F " " '{print$2}')

HOSTS_STATUS=`cat /etc/hosts | grep $host_ip`

if [  -z  "${HOSTS_STATUS}"  ]
then
	set_hostname
else
	log_info "hostname had seted"
fi
cat /etc/hosts|grep `hostname`
if [ $? -eq 0 ]
then
	log_info "removing old hostname:${NAMEHOST} entry in hosts"
	sed -i '/'''$NAMEHOST'''/d' /etc/hosts
	set_hostname
fi

#set NTP server
if  [ -f /etc/openstack-kilo_tag/install_ntp.tag ]
then
	log_info "ntp had installed."
else
	install_ntp
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

#NFS 
if  [ -f /etc/openstack-kilo_tag/install_nfs.tag ]
then
	log_info "nfs  had configured."
else
	nfs-export
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
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/openstack_ctr-nodes_prepare.tag
echo -e "\033[41;37m master controller node system prepare complete successful! \033[0m" 


read -p "Are you sure you will continue initial slave nodes[y/n]?:" INPUT
if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
	exit
elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
    then
    echo "will initial slave  nodes"
	/usr/bin/bash openstack_slave_nodes_stat.sh
fi

###########################master controller initial finish#########################