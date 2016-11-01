#/usr/bin/bash
#this script will change default ifcfg-enoxxxx to ifcfg-ethx 

ls -l /etc/sysconfig/network-scripts|awk  '/ifcfg-eno[0-9]*/ {print $9}' > default_nic_name.txt
i=0
cat default_nic_name.txt| while read line
do
	cd /etc/sysconfig/network-scripts
	name=$(echo $line|cut -b 7-)
	cp $line ${line}.bak
	sed -i "s/$name/eth${i}/g" $line
	sed -i 's/ONBOOT=no/ONBOOT=yes/g' $line
	mv $line ifcfg-eth${i}
	i=$(expr $i + 1)

done

sed -i '/GRUB_CMDLINE_LINUX=/d' /etc/default/grub 
echo 'GRUB_CMDLINE_LINUX="rd.lvm.lv=centos/root rd.lvm.lv=centos/swap crashkernel=auto net.ifnames=0 biosdevname=0 rhgb quiet"' >> /etc/default/grub 
grub2-mkconfig -o /boot/grub2/grub.cfg
reboot
