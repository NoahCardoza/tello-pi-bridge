#!/bin/bash

if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

nmcli device wifi rescan
nmcli dev wifi connect TELLO-632E40

WIRELESS_INTERFACE_INFO=$(ifconfig wlan0)

# Use grep to find the line containing 'inet' and awk to extract the IP address
PI_IP=$(echo "$WIRELESS_INTERFACE_INFO" | grep -o 'inet [0-9.]\+' | awk '{print $2}')

DRONE_IP=$(echo "$PI_IP" | cut -d. -f1-3).1
MAC_IP="192.168.2.1"

# If you want to use your phone to monitor the drone, you can add your phone's IP address to the array.
# It should be "192.168.10.3". You can find your phone's IP address by going to the WiFi settings on your phone.
#  e.g.: IPS_TO_FORWARD_DRONE_PACKETS_TO=($MAC_IP "192.168.10.3")
IPS_TO_FORWARD_DRONE_PACKETS_TO=($MAC_IP)


# Function to clean up on exit
cleanup() {
  pkill -P $$ # Kill all background processes started by this script
}

# Trap Ctrl+C (SIGINT) and call cleanup function
trap cleanup INT

function forward_tello_comms() {
    interface=$1
    from_ip=$2
    to_ip=$3
    should_fwd_cmd_packets=$4

    socat UDP4-LISTEN:11111,bindtodevice=$interface,fork,range=$from_ip/32 UDP4-SENDTO:$to_ip:11111 &
    # control packets only need to be forwarded for the mac
    # they don't need to be forwarded for the phone since
    # the phone is on the drone's wifi network
    if [[ $should_fwd_cmd_packets ]]; then
      socat UDP4-LISTEN:8889,bindtodevice=$interface,fork,range=$from_ip/32 UDP4-SENDTO:$to_ip:8889 &
    fi
    socat UDP4-LISTEN:8890,bindtodevice=$interface,fork,range=$from_ip/32 UDP4-SENDTO:$to_ip:8890 &
}

fwd_commands=true
for ip in "${IPS_TO_FORWARD_DRONE_PACKETS_TO[@]}"; do
    forward_tello_comms "wlan0" "$DRONE_IP" "$ip" $fwd_commands
    unset fwd_commands
done

forward_tello_comms "eth0" "$MAC_IP" "$DRONE_IP" true

echo "Forwarding Tello packets between:"
for ip in "${IPS_TO_FORWARD_DRONE_PACKETS_TO[@]}"; do
    echo "  $DRONE_IP <-> $ip"
done

wait
