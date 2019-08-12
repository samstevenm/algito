#!/usr/bin/env bash
# Timestamp function, used when saving client config files.
timestamp() {
  date +"%Y-%m-%d_%H-%M-%S"
}

# Randomize 4th octect, not a valid long term solution as duplicates are possible
rndOctet() {
  shuf -i 50-250 -n 1
}

# # Genkeys function #oldway
# genkeys() {
 # wg genkey | sudo tee /etc/wireguard/keysAndConfs/$1-pri | wg pubkey | sudo tee /etc/wireguard/keysAndConfs/$1-pub
# }

# Genkeys function
genServerKeys() {
	serverPrivateKey="$(wg genkey)"
	echo ----------------------------------------------------------------------
	echo serverPrivateKey:
	echo ----------------------------------------------------------------------
	echo "$serverPrivateKey" | sudo tee -a /etc/wireguard/keysAndConfs/serverPrivateKey
	echo
	echo ----------------------------------------------------------------------
	echo serverPublicKey:
	serverPublicKey="$(echo "$serverPrivateKey" | wg pubkey)"
	echo ----------------------------------------------------------------------
	echo "$serverPublicKey" | sudo tee -a /etc/wireguard/keysAndConfs/serverPublicKey
	
}
createServerConf() {
	echo ----------------------------------------------------------------------
	echo /etc/wireguard/wg0.conf:
	echo ----------------------------------------------------------------------
	echo 
	cat  << EOF | sudo tee -a /etc/wireguard/wg0.conf

[Interface]
Address = $octet1_3.1/24
PrivateKey = $serverPrivateKey
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens3 -j MASQUERADE
ListenPort = 51820

EOF

}

#Generate client device private and public keys
genDeviceKeys() {
	devicePrivateKey="$(wg genkey)"
	devicePublicKey="$(echo "$devicePrivateKey" | wg pubkey)"
	#Show on-screen then append to devices.list "json"
	echo ----------------------------------------------------------------------
	echo Appending to /etc/wireguard/devices.list:
	echo ----------------------------------------------------------------------
	echo 

	cat  << EOF | tee -a /etc/wireguard/devices.list
{
	{ deviceUniqueID :" "$deviceUniqueID" },
	{ deviceIP :" "$octet1_3.$octet4" },
	{ devicePrivateKey :" "$devicePrivateKey" },
	{ devicePublicKey :" "$devicePublicKey" }
},

EOF
	#Show on-screen then append client info to wg0.conf
	echo ----------------------------------------------------------------------
	echo Appending to wg0.conf:
	echo ----------------------------------------------------------------------
	echo 

	cat  << EOF | sudo tee -a /etc/wireguard/wg0.conf

[Peer]
#$deviceUniqueID
PublicKey = $devicePublicKey
AllowedIPs = $octet1_3.$octet4/32

EOF
}

#Create a device config file for use with a client device
createDeviceConf() {
	#read the serverPublicKey file
	serverPublicKey="$(sudo cat /etc/wireguard/keysAndConfs/serverPublicKey)"
	echo ----------------------------------------------------------------------
	echo /etc/wireguard/keysAndConfs/"$deviceUniqueID".conf:
	echo ----------------------------------------------------------------------
	echo 
	#create the device config file
	cat  << EOF | sudo tee -a /etc/wireguard/keysAndConfs/"$deviceUniqueID".conf
[Interface]
PrivateKey = $devicePrivateKey
Address = $octet1_3.$octet4/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = $serverPublicKey
Endpoint = <change_to_your_server>:51820
AllowedIPs = 0.0.0.0/0, ::/0

EOF

#create and then show a QR code for iOS
qrencode -t ansiutf8 < /etc/wireguard/keysAndConfs/"$deviceUniqueID".conf
qrencode -t ansiutf8 -o "$deviceUniqueID".png < /etc/wireguard/keysAndConfs/"$deviceUniqueID".conf
}

#This is the main script
main() {

# Create a directory to store server public and private keys and configurations files for clients (-p if it doesn't exist)
sudo mkdir -p /etc/wireguard/keysAndConfs/
sudo chmod -R 755 /etc/wireguard/keysAndConfs/

#get an cleint device id (file name) from arg1 or just set it to the current timestamp
deviceUniqueID=wg_${1:-"client"}_"$(timestamp)"

# Fixed octets 1 thru 3
octet1_3="10.0.254"

#get a 4th octect from arg2 or set it to a random number
octet4=${2:-"$(rndOctet)"}


#Stop wireguard
sudo wg-quick down wg0

#If the server config file and keys aren't created. Create them.
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "Config File not found! Generating Server Keys first."
	genServerKeys
	createServerConf
fi

#Generate client device private and public keys
genDeviceKeys

#Create a device config file for use with a client device
createDeviceConf

#Start wireguard
sudo wg-quick up wg0
}

main

