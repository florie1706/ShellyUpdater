########################################################################################
#
#  ShellyUpdater
#
#  Update your shelly devices thru this script. You will need the following packages
#  to be installed in advance:
#  - avahi-utils
#  - jq
#  - webserver (which is running to serve zip file for the firmware update
#
#  Please set these variables first:
#  - WWWDIR where the firmware update has to be stored
#  - WWWURL URL where your webserver can be reached from any device within your network
#  - USER shelly user, should be the same on every device within your network
#  - PW password, should be the same on every device within your network
#
#  Florie1706, 2020
#
########################################################################################
#
#  This programm is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
########################################################################################

#!/bin/bash

#### set colors for colorised output ####
red=`tput setaf 1`
green=`tput setaf 2`
blue=`tput setaf 4`
yellow=`tput setaf 3`
reset=`tput sgr0`

#### www directory where update file will be stored to use it for local ota ####
WWWDIR=/tmp
WWWURL=http://192.0.0.0

#### shelly login credicals ####
USER=admin
PW=secret

#### check for availible shellies in your network ####
for SHELLYIP in $(avahi-browse -d local -k -v -t -r -p _http._tcp | grep shelly | grep 192 | cut -d';' -f8)
	do
		SHELLYTYPE=$(curl -s http://$USER:$PW@$SHELLYIP/settings | jq .device.type | cut -d'"' -f2)
		OLDFIRMWARE=$(curl -s http://$USER:$PW@$SHELLYIP/settings | jq .fw | cut -d '"' -f2 | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
		NEWFIRMWARE=$(curl -s https://api.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].version' | cut -d '"' -f2 | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)

#### if no firmware version or shelly type is determinated an error message will be shown ####
	if [ -n $OLDFIRMWARE ] && [ -n $SHELLYTYPE ] ; then
#### check for newer firmware availible ####
		OLDFIRMWAREPART1=$(echo $OLDFIRMWARE | cut -d '.' -f1)
		NEWFIRMWAREPART1=$(echo $NEWFIRMWARE | cut -d '.' -f1)
		OLDFIRMWAREPART2=$(echo $OLDFIRMWARE | cut -d '.' -f2)
		NEWFIRMWAREPART2=$(echo $NEWFIRMWARE | cut -d '.' -f2)
		OLDFIRMWAREPART3=$(echo $OLDFIRMWARE | cut -d '.' -f3)
		NEWFIRMWAREPART3=$(echo $NEWFIRMWARE | cut -d '.' -f3)
		OLDFIRMWARESUM=$(((OLDFIRMWAREPART1 * 1000) + (OLDFIRMWAREPART2 * 100) + OLDFIRMWAREPART3))
		NEWFIRMWARESUM=$(((NEWFIRMWAREPART1 * 1000) + (NEWFIRMWAREPART2 * 100) + NEWFIRMWAREPART3))
		if [ $OLDFIRMWARESUM -lt $NEWFIRMWARESUM ] ; then
			echo "$SHELLYIP ($SHELLYTYPE) ${yellow}Update auf Version ${blue}$NEWFIRMWARE ${yellow}vorhanden${reset}."
			FIRMWAREURL=$(curl -s https://api.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].url' | cut -d '"' -f2)
			NEWFIRMWAREZIP=$(curl -s https://api.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].version' | cut -d '"' -f2 | cut -d '/' -f2 | cut -d '@' -f1)
#### download firmware to server or skip if it is already there ####
			if [ -f $WWWDIR/$SHELLYTYPE-$NEWFIRMWAREZIP.zip ] ; then
				echo "Firmware-Datei bereits vorhanden, überspringe Download"
			else
				echo "Lade Firmware-Datei herunter."
				curl -s $FIRMWAREURL --output $WWWDIR/$SHELLYTYPE-$NEWFIRMWAREZIP.zip
			fi
#### send firmware update to shelly ####
			echo "Starte Firmware-Update bei $SHELLYIP ($SHELLYTYPE) "
			curl -s http://$USER:$PW@$SHELLYIP/ota?url=$WWWURL/$SHELLYTYPE-$NEWFIRMWAREZIP.zip > /dev/null 2>&1
		else
			echo "$SHELLYIP ($SHELLYTYPE) ist ${green}up-to-date${reset}."
        	fi
	else
                echo "${red}Für $SHELLYIP konnte keine Firmware-Information abgerufen werden.${reset}"
	fi
done
