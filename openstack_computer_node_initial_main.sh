#!/usr/bin/bash

#function of this script:
#1.build ssh credit between master controller and computer nodes
#2.scp all scripts to computer nodes
#3.confirm that whether this node already been initiated or not
#4.change this node's nic_name from enoxxx form to ethx form and reboot system
#5.make remote yum repo based http for compute nodes to install nfs
#6.call openstack_compute_node_system_prepare.sh to start initial computer node
#7.make pacemaker cluster authkey and cross it to all controller nodes and computer nodes in cluster



compute_num=$(/usr/bin/bash readini.sh cluster_variables.ini computer node_num)
int_ip_set=$(/usr/bin/bash readini.sh cluster_variables.ini computer inter_ip_set)
ext_ip_set=$(/usr/bin/bash readini.sh cluster_variables.ini computer ext_ip_set)
ip_node[1]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node1_ip)
ip_node[2]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node2_ip)
ip_node[3]=$(/usr/bin/bash readini.sh cluster_variables.ini default ha_node3_ip)
NFS_SERVER=`hostname`
ISO_REPO=$(/usr/bin/bash readini.sh cluster_variables.ini controller1-vm rpm_web)

for ((i=1;i<=$compute_num;i++))
do
	hostname=computer${i}
	int_ip=$(echo $int_ip_set|cut -d ";" -f $i)
	echo $int_ip
	int_ip_arr[$i]=$int_ip
	ext_ip=$(echo $ext_ip_set|cut -d ";" -f $i)
expect << EOF
spawn ssh-copy-id root@$int_ip
    expect {
	    "yes/no" {send "yes\r";exp_continue}
	    "password" {send "root\r";exp_continue}
}
EOF
        
    #whether this compute node alread have been initiated or not,if YES,we initial next  compute node
    ssh $int_ip "ls -l /etc/openstack-kilo_tag/presystem_compute_node.tag"
    if [ $? -eq 0 ]
        then
        echo -e "\033[41;37m your ${i}th compute node already have been initiated,we will initial next compute node \033[0m"
        continue
    fi

    #whether need change NIC name from enoxxx as standard ethx form or not
    scp change_default_nic_name.sh $int_ip:/root
    ssh $int_ip "ip addr|grep eno"
    if [ $? -eq 0 ]
        then
        echo -e "\033[41;37m your nic_name is enoxxx form,we change it as ethx form,your system will reboot and you need run this script again! \033[0m"
        ssh $int_ip "/usr/bin/bash change_default_nic_name.sh"
        sleep 10
        while ! ping -c 2 $int_ip; do
            echo -e "\033[41;37mThe ${i}th compute node is rebooting.......\033[0m"
            sleep 1
        done  
    else
        echo  "your system do not need change nic_name formation!"
    fi

    #set remote yum repo for your compute node to install NFS,because of minal installation do not install NFS
    ssh $int_ip "mkdir -p /etc/yum.repos.d/bak && mv *.repo bak"
    cp /etc/yum.repos.d/centos7-iso.repo /etc/yum.repos.d/centos7-iso-tmp.repo
    sed -i "s/baseurl=file:\/\/\/data\/ISO/baseurl=http:\/\/192.168.142.21\/rpm/g" /etc/yum.repos.d/centos7-iso-tmp.repo
    scp /etc/yum.repos.d/centos7-iso-tmp.repo $int_ip:/etc/yum.repos.d/
    rm -rf /etc/yum.repos.d/centos7-iso-tmp.repo

    scp openstack_compute* $int_ip:/root
    scp cluster_variables.ini $int_ip:/root
    scp readini.sh $int_ip:/root
    scp /etc/hosts $int_ip:/etc/
    echo "beging initial ${i}th compute node system"
    ssh $int_ip "/usr/bin/bash openstack_compute_node_system_prepare.sh $NFS_SERVER $hostname $int_ip"

    sed -i "/$hostname/d" /etc/hosts
    echo "$int_ip $hostname" >> /etc/hosts
done

# both all controllers and compute nodes need have same pacemaker cluster connection authkey 
if [ ! -e /data/pcmk-authkey ]; then
   dd if=/dev/urandom of=/data/pcmk-authkey bs=4096 count=1
fi

for controller in 1 2 3
do
    ssh ${ip_node[$controller]} "rm -rf /etc/pacemaker && mkdir -p /etc/pacemaker && cp /data/pcmk-authkey /etc/pacemaker/authkey"
    scp /etc/hosts ${ip_node[$controller]}:/etc/
done


for ((i=1;i<=$compute_num;i++))
do
	scp /etc/hosts ${int_ip_arr[$i]}:/etc/
    ssh ${int_ip_arr[$i]} "rm -rf /etc/pacemaker && mkdir -p /etc/pacemaker && cp /data/pcmk-authkey /etc/pacemaker/authkey"
    ssh ${int_ip_arr[$i]} "chkconfig pacemaker_remote on && service pacemaker_remote start"
done
