# Tello Pi Bridge

## Introduction

This guide explains how to use a Rasberry Pi 4B to connect to a Tello drone via Ethernet. This is useful for situations where you'd like your host machine to maintain an Internet connection while communicating with a Tello drone. Usually this isn't possible since the Tello drone broadcasts it's own WiFi and you must connect your machine to it to communicate with it.


## Requirements

- Mac
- Raspberry Pi 4B
- Tello Drone

## (Optional) Setting up a Serial Connection to the Raspberry Pi

If you don't have an extra monitor/keyboard/mouse to connect to the Raspberry Pi, you can set up a serial connection to the Raspberry Pi. This will allow you to connect to the Raspberry Pi via a USB cable. A USB to TTL serial cable is required for this. Here is the one I used:

https://www.amazon.com/dp/B07DP7SPNH

This can be helpful since when messing with network configurations you often need to reset your network services which will disconnect you from the Raspberry Pi if you're connected via SSH.

To set this up, you'll need to update the Raspberry Pi's boot configuration. Run the following command:

```bash
sudo nano /boot/firmware/config.txt
```

Add the following line to the file:

```bash
enable_uart=1
```

Save the file and exit the editor. Now we need to update the Raspberry Pi's serial configuration. Run the following command:

```bash
sudo nano /boot/firmware/cmdline.txt
```

Add the following line to the beginning of the file. It is important that this is placed on the same line as the rest of the text in the file. Make sure there is a space between this and the existing text.

```txt
console=serial0,115200
```

Save the file, exit the editor, and reboot pi with `sudo reboot`.

Once the Raspberry Pi has rebooted, you can connect the USB to TTL serial cable to the Raspberry Pi and your host machine. You can then use a serial terminal program like `screen` to connect to the Raspberry Pi.

To connect to the Raspberry Pi using `screen`, first find the name of the serial port on your host machine. Run the following command:


```bash
ls /dev/tty.usbserial*
```

You should see a device named something like `/dev/tty.usbserial-XXXX`. This is the serial port. Now you can connect to the Raspberry Pi using the following command:

```bash
screen /dev/tty.usbserial-XXXX 115200 --fullscreen
```

You should now see the Raspberry Pi's console output. You can now interact with the Raspberry Pi as if you were connected to it via a monitor and keyboard.

## Setting Static IPs

## On the Mac

On the Mac, we need to set a static IP for the Ethernet interface. This is so we can communicate with the Tello drone over a wired connection.

To list all network services on your Mac, run the following command:

```bash
networksetup -listallnetworkservices
```

You should see a service named something along the lines of `USB 10/100/1000 LAN`, it may differ depending on the USB(-C) adapter you are using. This is the Ethernet interface. We need to set a static IP for this interface. To do this, we need to modify the network interfaces file. Run the following command:


```bash
networksetup -setmanual "USB 10/100/1000 LAN" 192.168.2.1 255.255.255.0
```

You can confirm the changes have taken effect by running the following command:

```bash
ifconfig
```

You should see one of the interfaces now has the IP address `192.168.2.1`.

## On the Raspberry Pi

On the Raspberry Pi, we need to set a static IP for the Ethernet interface. This is so we can communicate with the Tello drone over a wired connection.


First, we need to find the name of the Ethernet interface. Run the following command:


```bash
ifconfig
```

You should see an interface named `eth0`. This is the Ethernet interface. We need to set a static IP for this interface. To do this, we need to modify the network interfaces file. Run the following command:


```bash
sudo nano /etc/network/interfaces.d/eth0-static-ip.conf
```

Add the following lines to the file:

```bash
auto eth0
iface eth0 inet static
    address 192.168.2.2
    netmask 255.255.255.0
```

Save the file and exit the editor. Now we need to restart the networking service to apply the changes. Run the following command:

```bash
sudo systemctl restart networking
```

**Note**: If you're connected to the Raspberry Pi via SSH, this will disconnect you from the Raspberry Pi. You can reconnect to the Raspberry Pi using the static IP you set earlier.

## Connecting the Pi to the Drone's WiFi

Now that we have set static IPs for both the Mac and the Raspberry Pi, we can connect the Raspberry Pi to the Tello drone's WiFi. This is so we can communicate with the Tello drone over a wireless connection.

First, power on the Tello drone. Once the Tello drone has booted up and the WiFi is ready to connect (the light on the drone will be blinking yellow), run the following command on the Raspberry Pi:

```bash
sudo nmcli device wifi rescan
sudo nmcli device wifi scan
```

You may need to wait a few seconds and run the last command a few times until you see the Tello drone's WiFi network in the list of available networks. The network name should be something like `TELLO-XXXXXX`.

Now we can connect to the Tello drone's WiFi network. Run the following command:

```bash
sudo nmcli device wifi connect TELLO-XXXXXX
```

You should now be connected to the Tello drone's WiFi network. You can confirm this by running the following command:

```bash
ping 192.168.10.2 -c 1
```

## Communicating from your Mac to the drone

Now that we have connected the Raspberry Pi to the Tello drone's WiFi network, we can **ALMOST** communicate with the Tello drone from the Mac.

The last step is to run the tello-forward.sh script which can be found in the repository on the Pi. The reason we cannot simply setup packet forwarding
is becaus the drone uses UDP and the packets addressed to the 192.168.10.2 host no matter which hosts send them UDP packets. The tello-forward.sh script
sets up bidirectional forwarding between the Mac and the drone, sending all packets from the Mac to the Pi on ports 11111, 8889, and 8890 to the drone and vice versa.

If you'd like to monitor the drone from the Tello app while running scripts on your Mac, see the comments in the tello-forward.sh script for instructions on how to do this.

Before you can do this, you'll need to install `socat` on the Pi. Run the following command:

```bash
sudo apt-get install socat
```

Now you can run the tello-forward.sh script. Run the following command:

```bash
sudo ./tello-forward.sh
```

If you get a "Permission denied" error, you may need to make the script executable. Run the following command:

```bash
sudo chmod +x tello-forward.sh
```

Now on your Mac, you can use the standard Tello SDK commands to communicate with the Tello drone. All you need to do is set the host parameter to the IP address of your Pi when initiating the Tello class.

```py
from djitellopy import Tello

tello = Tello(host='192.168.2.2')
tello.connect()

tello.takeoff()

tello.land()
```

If you've yet to install the Tello SDK, you can do so by running the following command:

```bash
pip install djitellopy
```

## Conclusion

You should now be able to connect to a Tello drone via Ethernet using a Raspberry Pi 4B. This is useful for situations where you'd like your host machine to maintain an Internet connection while communicating with a Tello drone. Usually this isn't possible since the Tello drone broadcasts it's own WiFi and you mush connect your machine to it to communicate with it.

If you connect other devices to the drone's WiFi network, make sure to connect the Pi first. The drone only sends UDP packets to 192.168.10.2 which is assigned to the first device that connects to it. While you'll be able to control the drone from your phone, you won't be getting the state packets from the drone since your phone's IP address will be 192.168.10.3. If you'd like to monitor the drone from the Tello app while running scripts on your Mac, see the comments in the tello-forward.sh script for instructions on how to do this.
