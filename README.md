# Openstack-HA-Deployment

This Project was based on the book《Openstack HA and Operation》，before reading this project codes，we suggest to read the book firstly，so you can understand the theory of Height Availability Openstack cluster.

Environment<br>
1.Linux system：centos71 or centos72<br>
2.Openstack release:kilo(RDO)<br>

Introduction of Project<br> 
This Project implement Openstack HA deployment based on Pacemaker and HAProxy.To implement Openstack HA production environment，we overcover all components that relative with openstack，including low-level infrastructure components，such as 
rabbitMQ,HAProxy,mariadb,mongodb,memcached and so on，of course also including top-level Openstack core components，such as 
nova,neutron,cinder,glance,keystone,ceilometer,horizon and heat.Further more，we implement instance HA based on Pacemaker OCF monitor scripts，it can evacuate your instances on the failure hosts to normal running Nova compute nodes automatically，this function just like vmware FT，so you can do not care your virtual host(instances)any more.

How to do implement<br>
If anyone want to know about the details of this project and How to do implement Openstack HA，please reference the 11st chapter and 12st chapter of the above mentioned book.The chapters describe and tell you how do implement Openstack HA cluster step by step，of course，all scripts used by the book included in this project.Here,we just introduce the main point of Openstack HA deployment.Generally,Openstack cluster software stack consist of infrastructure softwares that are usually open source and top-level components that belong to openstack service projects.As Openstack community statement,the height availability of openstack should be the responsibility of infrastructure software,no openstack itself.Therefore, many vendors height availability solutions adopt the third-party software,such as pacemaker,keepalived and haproxy,and there are two main combinations,it is that pacemaker with haproxy and keepalived with haproxy,however,the HA solution with pacemaker and haproxy is seemly more suitable for production environment，so this project take it as Openstack HA solution.
   
In this Openstack HA deployment project,Pacemaker was selected as cluster resource management(CRM),HAProxy was selected as load balance,and every openstack service provided by a virtual IP(VIP),in addition,every VIP was treated as Pacemaker resource,and distributed all controller nodes evenly，in this project，there are three controller nodes.
   
To implement HA for all services,the systemd will not manage height availability services any more,but pacamaker manage those services automatically.The services needed implement height availability include HAproxy ,MariaDB ,mongoDB ,rabbitMQ ,Memcache ,Redis ,Nova,Glance,Cinder,Neutron,Keystone,Heat,Ceilometer.when you finish Openstack HA deploy according to this project,if every step is normal,you will get result as example-result.rst file.
