#! /bin/sh
# proxycannon-ng
#

###################
# install software
###################
# update and install deps
apt update
apt -y upgrade
apt -y install unzip git openvpn easy-rsa

# install terraform
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update -y
sudo apt-get install terraform -y

# create directory for our aws credentials
mkdir ~/.aws
touch ~/.aws/credentials
chown ubuntu:ubuntu   ~/.aws/credentials
################
# setup openvpn
################
# cp configs
cp configs/node-server.conf /etc/openvpn/node-server.conf
cp configs/client-server.conf /etc/openvpn/client-server.conf
cp configs/proxycannon-client.conf ~/proxycannon-client.conf

# setup ca and certs
mkdir /etc/openvpn/ccd
#clean up old setup
rm -rf /etc/openvpn/easy-rsa
#create new easy-rsa folder and init pki
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa/
/etc/openvpn/easy-rsa/easyrsa init-pki #initial public-private key infra
openssl rand -out /etc/openvpn/easy-rsa/pki/.rnd -hex 256 #fix .rnd cannot be loaded
#set openssl config
echo "set_var EASYRSA_SSL_CONF       \"/etc/openvpn/easy-rsa/openssl-easyrsa.cnf\"" >> /etc/openvpn/easy-rsa/vars
echo "set_var EASYRSA_REQ_CN=proxycannon-server" >> /etc/openvpn/easy-rsa/vars #set common name
echo "set_var EASYRSA_BATCH       \"yes\"" >> /etc/openvpn/easy-rsa/vars #stop build-ca asking for common name
#build ca
/etc/openvpn/easy-rsa/easyrsa build-ca nopass
#generate Diffie-hellman param
cd /etc/openvpn/easy-rsa/
./easyrsa gen-dh
#generate secret hmac
openvpn --genkey --secret /etc/openvpn/easy-rsa/pki/ta.key
#generate cert
./easyrsa build-server-full server nopass
./easyrsa build-client-full client01 nopass

# start services
systemctl start openvpn@node-server.service
systemctl start openvpn@client-server.service

# modify client config with remote IP of this server
EIP=`curl -s http://169.254.169.254/latest/meta-data/public-ipv4`
sed -i "s/REMOTE_PUB_IP/$EIP/" ~/proxycannon-client.conf

###################
# setup networking
###################
# setup routing and forwarding
sysctl -w net.ipv4.ip_forward=1

#equal cost multipath load sharing, flow-based (not per packet)
# use L4 (src ip, src dport, dest ip, dport) hashing for load balancing instead of L3 (src ip ,dst ip)
#echo 1 > /proc/sys/net/ipv4/fib_multipath_hash_policy
sysctl -w net.ipv4.fib_multipath_hash_policy=1

# setup a second routing table
echo "50        loadb" >> /etc/iproute2/rt_tables

# set rule for openvpn client source network to use the second routing table
ip rule add from 10.10.10.0/24 table loadb

# always snat from eth0
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

############################
# post install instructions
############################
echo "Copy the client files at /home/ubuntu/client-files to your workstation" 
cp /etc/openvpn/easy-rsa/pki/ta.key /home/ubuntu/client-files/ta.key
cp /etc/openvpn/easy-rsa/pki/ca.crt /home/ubuntu/client-files/ca.crt
cp /etc/openvpn/easy-rsa/pki/issued/client01.crt /home/ubuntu/client-files/client01.crt
cp /etc/openvpn/easy-rsa/pki/private/client01.key /home/ubuntu/client-files/client01.key
cp ~/proxycannon-client.conf /home/ubuntu/client-files/proxycannon-client.conf
chmod -R 0755 /home/ubuntu/client-files/* #facilitate download process
echo "client files:"
ls -la /home/ubuntu/client-files/
echo "Client config file"
cat ~/proxycannon-client.conf

echo "####################### Be sure to add your AWS API keys and SSH keys to the following locations ###################"
echo "copy your aws ssh private key to ~/.ssh/proxycannon.pem and chmod 600"
echo "place your aws api id and key in ~/.aws/credentials"

echo "[!] remember to run 'terraform init' in the nodes/aws on first use"
