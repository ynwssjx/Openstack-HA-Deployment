#/usr/bin/bash

# function of this script:
# 1. download rpm from apache server on master by http protrol when install vm
# 2. configure host fence to guest can be fenced by fence_xvm
# 3. create inject script to inject into vm when install vm 
# 4. create guest base image
# 5. define guest resource XML file
# 6. create guest image based on the base_image and start guest domain xml  

#this script will use file as follow:
# 1.cluster_variables.ini
# 2.readini.sh

#when this scripts finished successful ,a guest name $(hostname)-vm will runing on host

#log function
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
  mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/openstack_ctr_nodes_vm_create.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
  mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/openstack_ctr_nodes_vm_create.log

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

#配置Apache服务器用以http下载rpm包
function configure_apache_server()
{
  yum install httpd -y
  echo "your apache server is running!" > /var/www/html/index.html
  if [ -f /etc/httpd/conf.d/autoindex.conf.bak ]
    then
    rm -rf /etc/httpd/conf.d/autoindex.conf
    cp /etc/httpd/conf.d/autoindex.conf.bak /etc/httpd/conf.d/autoindex.conf
  else
    cp /etc/httpd/conf.d/autoindex.conf /etc/httpd/conf.d/autoindex.conf.bak
  fi
  cat >> /etc/httpd/conf.d/autoindex.conf << EOF
Alias /rpm/ "/data/ISO/"
<Directory "/data/ISO/">
Options Indexes MultiViews FollowSymlinks
AllowOverride None
Require all granted
</Directory>
EOF
    systemctl enable httpd.service 
    systemctl restart httpd.service
    echo `date "+Y%-M%-D% H%:M%:S%"` > /etc/openstack-kilo_tag/apache.tag

}

#配置fence 文件
function configure_fence_file()
{
  yum install -y fence-virtd fence-virtd-multicast fence-virtd-libvirt fence*
  lastoct="$(hostname|fold -1|sed -n '$p')"

  cat > /etc/fence_virt.conf << EOF
fence_virtd {
        listener = "multicast";
        backend = "libvirt";
}
listeners {
        multicast {
                #key_file = "/etc/cluster/fence_xvm.key";
                address = "225.0.0.$lastoct";
                # 指定接口会使得guest端的fence_xvm -o list 一直timeout
                # interface = "$int_br_name";
                interface = "none";
        }
}
backends {
        libvirt { 
                uri = "qemu:///system";
        }
}
EOF

    mkdir -p /etc/cluster/
    echo $fence_xvm > /etc/cluster/fence_xvm.key

    systemctl enable fence_virtd
    systemctl start fence_virtd
    echo `date "+Y%-M%-D% H%:M%:S%"` > /etc/openstack-kilo_tag/fence.tag
}

#配置VM初始化脚本
function create_guest_inject_script()
{
  rm -rf virt-base.ks
  cat << EOF > virt-base.ks
install
text
reboot
rootpw root
lang en_US.UTF-8
keyboard us
network --bootproto dhcp
firewall --disabled --ssh
selinux --disabled
timezone --utc $targettz
bootloader --location=mbr --append="console=tty0 console=ttyS0,115200 rd_NO_PLYMOUTH serial text headless"
zerombr
clearpart --all --initlabel
autopart --type=lvm
skipx

%packages
@core
grep
gawk
bind-utils
vi
net-tools
tcpdump
wget
sos
nfs-utils
ntp
ntpdate
%end

%post

# ethX will do nicely thankyou
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules
rm -f /etc/udev/rules.d/70-persistent-net.rules

# Need PEERDNS=no on the external interface to make sure all lookups
# go to our gateway (otherwise setting setting hostname via dhcp wont
# work)
#
# MUST add 'DEVICE=ethX' when deleting 'HWADDR', otherwise you end up
# with crazy things like:
#
# [root@localhost ~]# ifdown eth0
# Device 'eth1' successfully disconnected.
#
# Let eth0 come up, but don't let it connect to avoid conflicting dhcp
# and naming issues
#
# /usr/share/doc/initscripts/sysconfig.txt

cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOT
NAME="eth0"
DEVICE="eth0"
ONBOOT=yes
BOOTPROTO=static
IPADDR=$ext_ip
NETMASK=255.255.255.0
GATEWAY=$ext_gw
TYPE=Ethernet
IPV4_FAILURE_FATAL=no
EOT

cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOT
NAME="eth1"
DEVICE="eth1"
ONBOOT=yes
BOOTPROTO=static
IPADDR=$int_ip
NETMASK=255.255.255.0
TYPE=Ethernet
EOT

#inject public key from host to guest
mkdir /root/.ssh
cat << _EOT_ >> /root/.ssh/authorized_keys
ssh-rsa $vm_key root@${nfs_server}
_EOT_

chmod 600 /root/.ssh/authorized_keys

mkdir /data
hostnamectl set-hostname $vm_name
echo "$host_ip $host_name" >> /etc/hosts
echo "$nfs_server_ip $nfs_server" >> /etc/hosts
echo "$int_ip $vm_name" >> /etc/hosts
echo "${nfs_server}:/data /data  nfs  defaults  0 0">> /etc/fstab

# echo "${nfs_server}:/etc/yum.repos.d /etc/yum.repos.d  nfs  defaults  0 0">> /etc/fstab
# Prevent DHCPNAK by removing stale leases
# Occurs if we clone the guest and change NICs
rm -f /var/lib/NetworkManager/dhclient-*.lease

# If hostname is anything other than 'localhost.localdomain', then
# NetworkManager wont bother looking up DNS/DHCP for the host name
# when the node boots:
#
# May  5 11:04:15 localhost NetworkManager[676]: <info>  Setting system hostname to 'rdo7-node1.vmnet.mpc.lab.eng.bos.redhat.com' (from address lookup)


rm -rf /etc/yum.repos.d/*

cat > /etc/yum.repos.d/${vm_name}.repo << EOT
[centos7-iso]
name=centos7-iso
baseurl=file:///data/ISO
gpgcheck=0
enabled=1
[openstack-common]
name=openstack common packages
baseurl=file:///data/rdo-openstack-kilo/openstack-common
gpgcheck=0
enabled=1
[openstack-kilo]
name=openstack kilo packages
baseurl=file:///data/rdo-openstack-kilo/openstack-kilo
gpgcheck=0
enabled=1
[rdo-epel]
name=extra packages enterprise linux
baseurl=file:///data/rdo-openstack-epel
gpgcheck=0
enabled=1
EOT

%end
EOF
    echo `date "+Y%-M%-D% H%:M%:S%"` > /etc/openstack-kilo_tag/guest_inject_scripts.tag

}

#创建image并制作VM
function create_base_vm()
{
  yum install -y virt-install 
  mkdir -p $vm_dir
  qemu-img create -f qcow2 -o preallocation=metadata ${vm_dir}/$vm_base $vm_disk


  virt-install --connect=qemu:///system \
    --network=bridge:$int_br_name,mac=$int_mac \
    --initrd-inject=./virt-base.ks \
    --extra-args="ks=file:/virt-base.ks console=tty0 console=ttyS0,115200 serial rd_NO_PLYMOUTH" \
    --name=centos7-base \
    --disk path=${vm_dir}/$vm_base,format=qcow2,cache=none \
    --ram $vm_ram \
    --vcpus=$vm_cpu \
    --check-cpu \
    --accelerate \
    --os-type linux \
    --os-variant rhel7 \
    --hvm \
    --location=$rpm_http \
    --graphics vnc,listen='0.0.0.0' \
     --noautoconsole

    fn_log "virt-install create vm"

    sleep 420
    echo `date "+Y%-M%-D% H%:M%:S%"` > /etc/openstack-kilo_tag/create_base_vm.tag


}

#修改vm's xml file，.xml文件是虚拟机资源定义文件，修改xml不是修改镜像本身，而是修改启动镜像的资源定义
#将之前生成的image拷贝到/localvms目录，并在此目录定义一个xml虚拟机文件，通过--base参数重新生成一个镜像。

function define_vm_xml()
{
  # which rsync >/dev/null 2>&1 || yum install -y rsync
  mkdir -p /localvms
  cp ${vm_dir}/$vm_base /localvms/

    cat<< -EOF > /localvms/template.xml
<domain type='kvm'>
  <name>$vm_name</name>
  <memory>${vm_ram}000</memory>
  <currentMemory>${vm_ram}000</currentMemory>
  <vcpu>${vm_cpu}</vcpu>
  <os>
    <type arch='x86_64' machine='pc'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/localvms/${vm_name}.img'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='bridge'>
      <mac address='$ext_mac'/>
      <source bridge='$ext_br_name'/>
      <model type='virtio'/>
    </interface>
    <interface type='bridge'>
      <mac address='$int_mac'/>
      <source bridge='$int_br_name'/>
      <model type='virtio'/>
    </interface>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <input type='tablet' bus='usb'/>
    <input type='mouse' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'/>
  </devices>
</domain>
-EOF
    cp /localvms/template.xml /localvms/${vm_name}.xml
    qemu-img create -b /localvms/$vm_base -f qcow2 /localvms/${vm_name}.img

    echo `date "+Y%-M%-D% H%:M%:S%"` > /etc/openstack-kilo_tag/define_vm_xml.tag

}


#启动虚拟机
#清除已经存在的虚拟机定义，通过define_vm_xml函数定义的XML文件启动/localvms目录中的新镜像
function virsh_start_vm()
{
  virsh list --all| grep running |awk -F " " '{printf("virsh destroy %s\n",$2)}'|sh
  virsh list --all |grep shut |awk -F " " '{printf("virsh undefine %s\n",$2)}'|sh
  virsh define /localvms/${vm_name}.xml
  virsh start ${vm_name}

  fn_log "start ${vm_name}.xml"
  sleep 40
  # ping $int_ip

}

#########################################main body#############################
targettz="$(timedatectl | grep Timezone | awk '{print $2}')"
    
if [ -z "$targettz" ]
  then
    targettz=Asia/Shanghai
fi
NFS_SERVER=controller1
host_name=`hostname`
section=`hostname`-vm
vm_dir=$(/usr/bin/bash readini.sh cluster_variables.ini $section image_dir) 
vm_cpu=$(/usr/bin/bash readini.sh cluster_variables.ini $section cpu) 
vm_ram=$(/usr/bin/bash readini.sh cluster_variables.ini $section ram) 
vm_disk=$(/usr/bin/bash readini.sh cluster_variables.ini $section disk)
vm_base=$(/usr/bin/bash readini.sh cluster_variables.ini $section base)
vm_key=$(/usr/bin/bash readini.sh cluster_variables.ini $section key)
int_mac=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_mac)
ext_mac=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_mac)
rpm_http=$(/usr/bin/bash readini.sh cluster_variables.ini $section rpm_web)
ext_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_ip)
ext_gw=$(/usr/bin/bash readini.sh cluster_variables.ini $section ext_gw)
int_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $section int_ip)
fence_xvm=$(/usr/bin/bash readini.sh cluster_variables.ini $section fence_xvm)
vm_name=$(/usr/bin/bash readini.sh cluster_variables.ini $section vm_name)
int_br_name=$(/usr/bin/bash readini.sh cluster_variables.ini $(hostname) inter_br0_name)
ext_br_name=$(/usr/bin/bash readini.sh cluster_variables.ini $(hostname) ext_br0_name)
host_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $(hostname) host_ip)
nfs_server=$(/usr/bin/bash readini.sh cluster_variables.ini $(hostname) nfs_server)
nfs_server_ip=$(/usr/bin/bash readini.sh cluster_variables.ini $(hostname) nfs_server_ip)

#install apache

if [ -f /etc/openstack-kilo_tag/apache.tag ]
  then
  more /etc/httpd/conf.d/autoindex.conf|grep -i rpm
  if [ $? -eq 0 ]
    then
    log_info "apache already confihured!"
  else
    configure_apache_server
  fi
  
else
  configure_apache_server
fi

#configure fence file
if [ -f /etc/openstack-kilo_tag/fence.tag ]
  then
  log_info "fence file already confihured"
else
  configure_fence_file
fi


#create guest inject script
if [ -f /etc/openstack-kilo_tag/guest_inject_scripts.tag ]
  then
  log_info "guest initial script already  created"
else
    create_guest_inject_script
fi

#create base image 
if [ -f /etc/openstack-kilo_tag/create_base_vm.tag ] || [ -f ${vm_dir}/$vm_base ]
  then
  log_info "base image already are created "
else
  if [ -d ${vm_dir} ]
    then
    rm -rf ${vm_dir}
  fi
  virsh list --all| grep running |awk -F " " '{printf("virsh destroy %s\n",$2)}'|sh
  virsh list --all |grep shut |awk -F " " '{printf("virsh undefine %s\n",$2)}'|sh
  create_base_vm
fi

#define xml file
if [ -f /etc/openstack-kilo_tag/define_vm_xml.tag ]
  then
  log_info "the XML file already changed"
else
  if [ -d /localvms ]
    then
    rm -rf /localvms
  fi
  define_vm_xml
fi

#start vm
echo "begining start xml file "
virsh_start_vm
fn_log "vm create"
log_info "start vm complete successful on master controller node!"

