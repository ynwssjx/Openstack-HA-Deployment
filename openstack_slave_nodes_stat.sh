#/usr/bin/bash

# this scripts called by openstack_master_ctr-nodes_prepare.sh
# function of this script:
# 1.seting the number of slave controller by interactive method
# 2.input hostname and ip of each slave  controller nodes
# 3.retrive ip of each nodes and output to nodes_ip_list
# 4.scp files need by scripts  to slave  nodes 
# 5.Looply call openstack_slave_ctr-nodes_prepare.sh to initial slave nodes 


#log function
function log_info ()
{
     DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
     USER_N=`whoami`
     if [ ! -d /var/log/openstack-kilo ] 
         then
     	 mkdir -p /var/log/openstack-kilo
     fi
         echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/openstack_slave_ctr-nodes_prepare.tag

}

function log_error ()
{
     DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
     USER_N=`whoami`
     if [ ! -d /var/log/openstack-kilo ] 
         then
     	 mkdir -p /var/log/openstack-kilo
     fi
         echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/openstack_slave_ctr-nodes_prepare.tag
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

#############################initial slave ctr nodes####################################
function If_reconfig_slave-ctr-nodes()
{
    read -p "Are you sure that you want reconfig your slave ctr nodes[y/n]: " INPUT
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
		 then
		 exit
	elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
		 then
		 echo "you will reconfig your slave ctr nodes!"
		 rm -rf /etc/openstack-kilo_tag/openstack_slave_ctr-nodes_prepare.tag
	else
		 If_reconfig_slave-ctr-nodes
	fi

}


if [ -f openstack_slave_ctr-nodes_prepare.tag ]
	 then
	 echo -e "\033[41;37m your system donot need config because it was configurated \033[0m"
	 log_info "your system donot need config because it was configurated."	
	 If_reconfig_slave-ctr-nodes
fi


# read -p "please input your HA openstack cluster slave ctr nodes number:" controller_num
# if [ -f controller_result.txt ]
#      then
# 	 rm -rf controller_result.txt
# 	 echo "ctr_num=${controller_num}" >>controller_result.txt
# else
# 	 echo "ctr_num=${controller_num}" >>controller_result.txt
# fi

nodes_ip_list=""
controller_num=$(/usr/bin/bash readini.sh cluster_variables.ini default slave_ctr_node_num) 

for ((i=1;i<=${controller_num};i++))
do
	 # read -p "please set your the ${i}st slave controller node's name:" controller_name
	 # read -p "please set your the ${i}st slave controller node's management ip:" compute_mng_ip
	 # read -p "please set your the ${i}st controller node's tunnel ip:" compute_tun_ip
	 # read -p "please set your the ${i}st controller node's storage data ip:" compute_data_ip
	 ctr_name[${i}]=$(/usr/bin/bash readini.sh cluster_variables.ini default slave${i})
	 ctr_mng_ip[${i}]=$(/usr/bin/bash readini.sh cluster_variables.ini default ip_slave${i})
	 # ctr_name[${i}]=${controller_name}
	 # com_tun_ip[${i}]=${compute_tun_ip}
	 # com_data_ip[${i}]=${compute_data_ip}
	 nodes_ip_list="$nodes_ip_list ${ctr_mng_ip[${i}]}"
 	 # echo "${controller_name}" >> controller_result.txt
	 # sed -i "s/${controller_name}/& ${ctr_mng_ip[${i}]}/" controller_result.txt
	 # sed -i "s/${ctr_mng_ip[${i}]}/& ${com_tun_ip[${i}]}/" controller_result.txt
	 # sed -i "s/${com_tun_ip[${i}]}/& ${com_data_ip[${i}]}/" controller_result.txt
	 
	 cat /etc/hosts|grep ${ctr_name[${i}]}
	 if [ $? -eq 0 ]
	 then
	 	log_info "removing old hostname:${ctr_name[${i}]} entry in hosts"
	 	sed -i '/'''${ctr_name[${i}]}'''/d' /etc/hosts
	 	echo "${ctr_mng_ip[${i}]} ${ctr_name[${i}]} " >>/etc/hosts
	 else
	 	echo "${ctr_mng_ip[${i}]} ${ctr_name[${i}]} " >>/etc/hosts
	 fi
	
done

if [ -f nodes_ip_list.txt ]
	 then
	 rm -rf nodes_ip_list.txt
	 echo $nodes_ip_list >> nodes_ip_list.txt
else
	 echo $nodes_ip_list >> nodes_ip_list.txt
fi


#信任互访，scp拷贝文件到远程slave nodes
/usr/bin/bash build-ssh-credit.sh nodes_ip_list.txt

#执行slave nodes的初始化
for ((i=1;i<=${controller_num};i++))
do
	 # ssh-copy-id root@${ctr_mng_ip[${i}]}
	 
	 ssh ${ctr_mng_ip[${i}]} "hostnamectl set-hostname ${ctr_name[${i}]}"
	 # scp /etc/hosts ${ctr_name[${i}]}:/etc/
	 # scp `pwd`/etc/openstack_slave_ctr-nodes_prepare.sh ${ctr_name[${i}]}:/root/
	 scp readini.sh ${ctr_mng_ip[${i}]}:/root/
	 scp cluster_variables.ini ${ctr_mng_ip[${i}]}:/root/
	 scp create_image_and_VM.sh ${ctr_mng_ip[${i}]}:/root/
	 echo -e "\033[41;37m starting config the ${i}st slave controller node system environment \033[0m" 
	 ssh ${ctr_mng_ip[${i}]} "/bin/bash /root/openstack_slave_ctr-nodes_prepare.sh  $(hostname)"
	 echo -e "\033[41;37m complete config the  ${i}st slave controller node system environment successful\033[0m" 
done

echo `date "+%Y-%m-%d %h:%m:%s"` > /etc/openstack-kilo_tag/openstack_slave_ctr-nodes_prepare.tag