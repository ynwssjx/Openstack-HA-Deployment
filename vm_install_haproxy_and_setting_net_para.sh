#!/usr/bin/bash

# function of this script:
# 1.install haproxy
# 2.coinfig kernel net paras to allow bind nolocal ip 

yum install -y haproxy
echo "net.ipv4.ip_nonlocal_bind=1" > /etc/sysctl.d/haproxy.conf

    
cat /etc/sysctl.conf|grep -i "ip_nonlocal_bind=1"
 if [ $? -eq 0 ]
 	then
 	sed -i '/net.ipv4.ip_nonlocal_bind=1/d' /etc/sysctl.conf
 	echo "/etc/sysctl.conf no need setted"
 	echo "net.ipv4.ip_nonlocal_bind=1" >> /etc/sysctl.conf
 else
 	echo "net.ipv4.ip_nonlocal_bind=1" >> /etc/sysctl.conf
 fi

sysctl -p 

echo 1 > /proc/sys/net/ipv4/ip_nonlocal_bind
# the keepalive settings must be set in *ALL* hosts interacting with rabbitmq.
cat >/etc/sysctl.d/tcp_keepalive.conf << EOF
net.ipv4.tcp_keepalive_intvl = 1
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 5
EOF
sysctl net.ipv4.tcp_keepalive_intvl=1
sysctl net.ipv4.tcp_keepalive_probes=5
sysctl net.ipv4.tcp_keepalive_time=5


#install rsyslog so that it can log haproxy events
yum instll -y rsyslog
sed -i '/^\$ModLoad/d' /etc/rsyslog.conf
sed -i '/^$UDPServerRun/d' /etc/rsyslog.conf
sed -i '/^local0/d' /etc/rsyslog.conf

echo "\$ModLoad imudp" >> /etc/rsyslog.conf
echo "\$UDPServerRun 514" >> /etc/rsyslog.conf
echo "local0.*        /var/log/haproxy.log" >> /etc/rsyslog.conf

systemctl enable rsyslog.service
systemctl restart rsyslog.service