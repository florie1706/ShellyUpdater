ShellyUpdater

Update your shelly devices thru this script.
Tested on Ubuntu 20.04 with a 192.-Network.
You will need the following packages to be installed in advance:
- avahi-utils
- jq
- webserver (which is running to serve the OTA-zip file for the firmware update)

Please set these variables first:
- WWWDIR where the firmware update has to be stored
- WWWURL URL where your webserver can be reached from any device within your network
- USER shelly user, should be the same on every device within your network
- PW password, should be the same on every device within your network
- TRUNK set to STABLE, PRE or BETA to check for the desired release channel

Florie1706, 2020
