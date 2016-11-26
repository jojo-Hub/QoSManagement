# QoSManagement

A Lua lib to maintain a list of QoS assignments in openWRT. Instead of assigning every IP an explicit priority, several IP-address ranges are assigned with a priority. This script then instructs the DHCP-server (/etc/hosts and /etc/ethers) to assign an IP of the desired priority range to a given mac address. Also, a hostname and a device type has to be assigned to improve readability. Since the hostname is written to /etc/hosts, the local DNS resolution applies to the given hostnames as well.

## Usage
In your Lua application, first load the library:

`QoSMLib = require "QoSMLib"`
  
Now, you my use the functions as there are
  - QoSMLib.add(<hostname>, <MAC>, <prio>, <device>)
  - QoSMLib.deleteIP(<IP>)
  - QoSMLib.printPrioList(<prio>)
  - QoSMLib.printAll()
  - QoSMLib.changePrio(<IP>, <newPrio>)
