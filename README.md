# Openstack-HA-Deployment

This Project was based on the book 《Openstack HA and operation》，before read this project codes，we suggest to read the book firstly，so you can understand the theory of Height Availability openstack cluster.

Environment：
1.Linux System：Centos71 or Centsos72                                                                                  2.Openstack:Kilo(RDO)

Introduction of Project：
This Project implement Openstack HA deployment based on Pacemaker and HAProxy.To implement Openstack HA production environment，we overcover all components that relative with openstack，such as rabbitMQ、HAProxy、mariadb、mongodb、memcached and so on，of course Openstack core components，example nova、neutron、cinder、glance、keystone、ceilometer、horizon and heat。Further more，we implement instance HA based on Pacemaker OCF monitor scripts，it can evacuate your instances on the failure host to normal compute node automatically，this function just like vmware FT，so you can do not care your virtual host（instances） any more.
