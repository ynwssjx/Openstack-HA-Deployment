#remove neutronscale RA

#step1:uncommont host entry in all configure files
sed -i '/^host = neutron/d' /etc/neutron/*.conf
sed -i '/^host = neutron/d' /etc/neutron/*.ini

#step2: drop neutron DB
drop database neutron;

#step3:create neutron DB and initial sync DB

#step4:create pacemaker resource and set constarint


# For A/P, set clone-max=1
# pcs resource create neutron-scale ocf:neutron:NeutronScale --clone globally-unique=true clone-max=3 interleave=true
pcs resource create neutron-server-api systemd:neutron-server op start timeout=180 --clone interleave=true
pcs resource create neutron-ovs-cleanup ocf:neutron:OVSCleanup --clone interleave=true
pcs resource create neutron-netns-cleanup ocf:neutron:NetnsCleanup --clone interleave=true
pcs resource create neutron-openvswitch-agent  systemd:neutron-openvswitch-agent --clone interleave=true
pcs resource create neutron-dhcp-agent systemd:neutron-dhcp-agent --clone interleave=true
pcs resource create neutron-l3-agent systemd:neutron-l3-agent --clone interleave=true
pcs resource create neutron-metadata-agent systemd:neutron-metadata-agent  --clone interleave=true


# pcs constraint order start neutron-scale-clone then neutron-openvswitch-agent-clone
# pcs constraint colocation add neutron-openvswitch-agent-clone with neutron-scale-clone
# pcs constraint order start neutron-scale-clone then neutron-ovs-cleanup-clone
# pcs constraint colocation add neutron-ovs-cleanup-clone with neutron-scale-clone

pcs constraint order start keystone-clone then neutron-server-api-clone 
pcs constraint order start neutron-server-api-clone then neutron-ovs-cleanup-clone
pcs constraint order start neutron-ovs-cleanup-clone then neutron-netns-cleanup-clone
pcs constraint order start neutron-netns-cleanup-clone then neutron-openvswitch-agent-clone
pcs constraint order start neutron-openvswitch-agent-clone then neutron-dhcp-agent-clone
pcs constraint order start neutron-dhcp-agent-clone then neutron-l3-agent-clone
pcs constraint order start neutron-l3-agent-clone then neutron-metadata-agent-clone

pcs constraint colocation add neutron-netns-cleanup-clone with neutron-ovs-cleanup-clone
pcs constraint colocation add neutron-openvswitch-agent-clone with neutron-netns-cleanup-clone
pcs constraint colocation add neutron-dhcp-agent-clone with neutron-openvswitch-agent-clone
pcs constraint colocation add neutron-l3-agent-clone with neutron-dhcp-agent-clone
pcs constraint colocation add neutron-metadata-agent-clone with neutron-l3-agent-clone
# pcs constraint order start neutron-server-api-clone then neutron-scale-clone
# pcs constraint order start keystone-clone then neutron-scale-clone

#step5: set osp=control
pcs constraint location neutron-server-api-clone  rule resource-discovery=exclusive score=0 osprole eq controller --force
pcs constraint location neutron-ovs-cleanup-clone  rule resource-discovery=exclusive score=0 osprole eq controller --force
pcs constraint location neutron-netns-cleanup-clone  rule resource-discovery=exclusive score=0 osprole eq controller --force
pcs constraint location neutron-openvswitch-agent-clone  rule resource-discovery=exclusive score=0 osprole eq controller --force
pcs constraint location neutron-dhcp-agent-clone  rule resource-discovery=exclusive score=0 osprole eq controller --force
pcs constraint location neutron-l3-agent-clone  rule resource-discovery=exclusive score=0 osprole eq controller --force
pcs constraint location neutron-metadata-agent-clone  rule resource-discovery=exclusive score=0 osprole eq controller --force

#step6:verify neutron agent
neutron  agent-list

#step:create ext-net,tenant-net,router
neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat
neutron subnet-create ext-net 192.168.115.0/24 --name ext-subnet --allocation-pool start=192.168.115.200,end=192.168.115.250  --disable-dhcp --gateway 192.168.115.254

neutron net-create admin-net
neutron subnet-create admin-net 192.128.1.0/24 --name admin-subnet --gateway 192.128.1.1

neutron router-create admin-router
neutron router-interface-add admin-router admin-subnet && neutron router-gateway-set admin-router ext-net




