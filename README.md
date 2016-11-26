# QoSManagement

A Lua lib to maintain a list of QoS assignments in openWRT. Instead of assigning every IP an explicit priority, several IP-address ranges are assigned with a priority. This script then instructs the DHCP-server (/etc/hosts and /etc/ethers) to assign an IP of the desired priority range to a given mac address. Also, a hostname and a device type has to be assigned to improve readability. Since the hostname is written to /etc/hosts, the local DNS resolution applies to the given hostnames as well.

## IP priority ranges
By default, the following ranges apply
| Priority   | assigned IP range |
| ------------- | ------------- |
| QoS default  | 172.16.128.0/20  |
| QoS high | 172.16.144.0/20 |
| QoS priority  | 172.16.160.0/20  |
| QoS express | 172.16.176.0/20 | 

## Usage
In your Lua application, first load the library:

`QoSMLib = require "QoSMLib"`
  
Now, you my use the functions as there are
  - QoSMLib.add(<hostname>, <MAC>, <prio>, <device>)
  - QoSMLib.deleteIP(<IP>)
  - QoSMLib.printPrioList(<prio>)
  - QoSMLib.printAll()
  - QoSMLib.changePrio(<IP>, <newPrio>)
