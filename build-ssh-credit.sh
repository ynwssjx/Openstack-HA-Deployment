#! /usr/bin/bash

expect << EOF
set timeout 10
spawn ssh-keygen -t rsa 
expect {
	"*to save the key" {send "\n";exp_continue}
	"*(y/n)" {send "y\r";exp_continue}
	"Enter passphrase" {send "\n";exp_continue}
	"Enter same passphrase" {send "\n";exp_continue}
}

EOF
 
 # ctr_num=`cat controller_result.txt|awk -F " " '{print $1}'`
 # echo "$ctr_num"

#$1 参数为slave nodes的ip list
for ip in `cat $1`
do

	expect << EOF
	set timeout 10
    spawn ssh-copy-id root@$ip
    expect {
	    "yes/no" {send "yes\r";exp_continue}
	    "password" {send "root\r";exp_continue}
}
    spawn scp /etc/hosts $ip:/etc
    expect {
	    "yes/no" {send "yes\r";exp_continue}
	    "password" {send "root\r";exp_continue}
}
    spawn scp openstack_slave_ctr-nodes_prepare.sh $ip:/root
    expect {
	    "yes/no" {send "yes\r";exp_continue}
	    "password" {send "root\r";exp_continue}
}
EOF
done

