sudo ip link add goapp link ens33 type ipvlan mode l3
sudo ip addr add 192.168.100.1/24 dev goapp
sudo ip link set goapp up

sudo ip link add db link ens33 type ipvlan mode l3
sudo ip addr add 192.168.101.1/24 dev db
sudo ip link set db up

sudo ip link add lb link ens33 type ipvlan mode l3
sudo ip addr add 192.168.102.1/24 dev lb
sudo ip link set lb up


sudo sysctl -w net.ipv4.ip_forward=1

echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p


sudo ip route add 192.168.100.0/24 dev goapp
sudo ip route add 192.168.101.0/24 dev db
sudo ip route add 192.168.102.0/24 dev lb


sudo ip link delete goapp
sudo ip link delete db
sudo ip link delete lb

sudo ip route delete 192.168.100.0/24
sudo ip route delete 192.168.101.0/24
sudo ip route delete 192.168.102.0/24


sudo ip link add ipvlan0 link ens33 type ipvlan mode l3
sudo ip addr add 192.168.150.0/24 dev ipvlan0
sudo ip link set ipvlan0 up

sudo ip route add 192.168.150.0/24 dev ipvlan0
sudo ip route add 192.168.150.0/24 via 192.168.174.128
