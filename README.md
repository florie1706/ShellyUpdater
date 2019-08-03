ShellyUpdater

Update your shelly devices thru this script.
Tested on Ubuntu 18.04 with a 192.-Network.
You will need the following packages to be installed in advance:
- avahi-utils
- jq
- webserver (which is running to server zip file for the firmware update

Please set these variables first:
- WWWDIR where the firmware update has to be stored
- WWWURL URL where your webserver can be reached from any device within your network
- USER shelly user, should be the same on every device within your network
- PW password, should be the same on every device within your network

Florie1706, 2019
