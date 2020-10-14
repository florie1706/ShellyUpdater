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
yellow=`tput setaf 3`
cyan=`tput setaf 6`
reset=`tput sgr0`

#### www directory where update file will be stored to use it for local ota ####
WWWDIR=/tmp
WWWURL=http://192.0.0.0

#### shelly login credicals ####
USER=admin
PW=secret

#### Release version ###
TRUNK=BETA

#### check for correct TRUNK version ####
if [ $TRUNK != "BETA" ] && [ $TRUNK != "PRE" ] ; then
        TRUNK=STABLE
fi

echo "${yellow}$TRUNK-Kanal wurde ausgewählt.${reset}"
ECHOTRUNK=0

#### check for availible shellies in your network ####
for SHELLYIP in $(avahi-browse -d local -k -v -t -r -p _http._tcp | grep helly | grep 192 | cut -d ';' -f8 | sort -n)
        do
        UPDATE=0
        SHELLYTYPE=$(curl -s http://$USER:$PW@$SHELLYIP/settings | jq .device.type | cut -d'"' -f2)
        OLDFIRMWAREFULL=$(curl -s http://$USER:$PW@$SHELLYIP/settings | jq .fw | cut -d '"' -f2)
        OLDFIRMWARE=$(echo $OLDFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
        STABLENEWFIRMWAREFULL=$(curl -s https://api.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].version' | cut -d '"' -f2)
        if [ $TRUNK = "STABLE" ] ; then
                NEWFIRMWAREFULL=$STABLENEWFIRMWAREFULL
        elif [ $TRUNK = "PRE" ] ; then
                PRENEWFIRMWAREFULL=$(curl -s https://repo.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].version' | cut -d '"' -f2)
                NEWFIRMWAREFULL=$PRENEWFIRMWAREFULL
        else
                PRENEWFIRMWAREFULL=$(curl -s https://repo.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].version' | cut -d '"' -f2)
                BETANEWFIRMWAREFULL=$(curl -s https://repo.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].beta_ver' | cut -d '"' -f2)
                NEWFIRMWAREFULL=$BETANEWFIRMWAREFULL
        fi
        NEWFIRMWARE=$(echo $NEWFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
        NEWFIRMWARECHECKSUM=$(echo $NEWFIRMWAREFULL | cut -d '@' -f2)
#### if no firmware version or shelly type is determinated an error message will be shown ####
        if [ -n "$OLDFIRMWARE" ] && [ -n "$SHELLYTYPE" ] ; then
#### check for newer firmware availible ####
                OLDFIRMWAREPART1=$(echo $OLDFIRMWARE | cut -d '.' -f1)
                OLDFIRMWAREPART2=$(echo $OLDFIRMWARE | cut -d '.' -f2)
                OLDFIRMWAREPART3=$(echo $OLDFIRMWARE | cut -d '.' -f3)
                OLDFIRMWARESUM=$(((OLDFIRMWAREPART1 * 10000) + (OLDFIRMWAREPART2 * 100) + OLDFIRMWAREPART3))
                OLDFIRMWARECHECKSUM=$(echo $OLDFIRMWAREFULL | cut -d '@' -f2)
                OLDFIRMWAREDATETIME=$(echo $OLDFIRMWAREFULL | cut -d '/' -f1)
                NEWFIRMWAREPART1=$(echo $NEWFIRMWARE | cut -d '.' -f1)
                NEWFIRMWAREPART2=$(echo $NEWFIRMWARE | cut -d '.' -f2)
                NEWFIRMWAREPART3=$(echo $NEWFIRMWARE | cut -d '.' -f3)
                NEWFIRMWARESUM=$(((NEWFIRMWAREPART1 * 10000) + (NEWFIRMWAREPART2 * 100) + NEWFIRMWAREPART3))
                NEWFIRMWARECHECKSUM=$(echo $NEWFIRMWAREFULL | cut -d '@' -f2)
                NEWFIRMWAREDATETIME=$(echo $NEWFIRMWAREFULL | cut -d '/' -f1)
#### check if newer version is availible and if there is a newer version then your choosen trunk on STABLE/PRE when PRE/BETA was selected) for new shipped devices the current firmware will be installed ####
                if ([ $NEWFIRMWARESUM -ge $OLDFIRMWARESUM ] && ([ $NEWFIRMWARECHECKSUM != $OLDFIRMWARECHECKSUM ] || [ $NEWFIRMWAREDATETIME != $OLDFIRMWAREDATETIME ])) || [ $OLDFIRMWARECHECKSUM > 99999 ] ; then
                        UPDATE=$TRUNK
                        if [ $TRUNK != "STABLE" ] ; then
                                STABLENEWFIRMWARE=$(echo $STABLENEWFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
                                STABLENEWFIRMWAREPART1=$(echo $STABLENEWFIRMWARE | cut -d '.' -f1)
                                STABLENEWFIRMWAREPART2=$(echo $STABLENEWFIRMWARE | cut -d '.' -f2)
                                STABLENEWFIRMWAREPART3=$(echo $STABLENEWFIRMWARE | cut -d '.' -f3)
                                STABLENEWFIRMWARESUM=$(((STABLENEWFIRMWAREPART1 * 10000) + (STABLENEWFIRMWAREPART2 * 100) + STABLENEWFIRMWAREPART3))
                                STABLENEWFIRMWAREDATETIME=$(echo $STABLENEWFIRMWAREFULL | cut -d '/' -f1)
                                if [ $STABLENEWFIRMWARESUM -eq $NEWFIRMWARESUM ] || [ $STABLENEWFIRMWAREDATETIME != $NEWFIRMWAREDATETIME ] ; then
                                        UPDATE=STABLE
                                        NEWFIRMWARE=$STABLENEWFIRMWARE
                                fi
                        fi
                        if [ $TRUNK = "BETA" ] ; then
                                PRENEWFIRMWARE=$(echo $PRENEWFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
                                PRENEWFIRMWAREPART1=$(echo $PRENEWFIRMWARE | cut -d '.' -f1)
                                PRENEWFIRMWAREPART2=$(echo $PRENEWFIRMWARE | cut -d '.' -f2)
                                PRENEWFIRMWAREPART3=$(echo $PRENEWFIRMWARE | cut -d '.' -f3)
                                PRENEWFIRMWARESUM=$(((PRENEWFIRMWAREPART1 * 10000) + (PRENEWFIRMWAREPART2 * 100) + PRENEWFIRMWAREPART3))
                                PRENEWFIRMWAREDATETIME=$(echo $PRENEWFIRMWAREFULL | cut -d '/' -f1)
                                if [ $PRENEWFIRMWARESUM -eq $NEWFIRMWARESUM ] || [ $PRENEWFIRMWAREDATETIME != $NEWFIRMWAREDATETIME ] ; then
                                        UPDATE=PRE
                                        NEWFIRMWARE=$PRENEWFIRMWARE
                                fi
                        fi
                fi
                if [ $UPDATE != $TRUNK ] && (([ $UPDATE = "PRE" ] && [ $PRENEWFIRMWAREDATETIME = $OLDFIRMWAREDATETIME ]) || ([ $UPDATE = "BETA" ] && [ $BETANEWFIRMWAREDATETIME = $OLDFIRMWAREDATETIME ])) ; then
                        UPDATE=0
                fi
                if [ $UPDATE != 0 ] ; then
                        if [ $ECHOTRUNK -eq 0 ] ; then
                                echo "${yellow}$UPDATE-Kanal hat neuere Firmware, $UPDATE wird nun verwendet.${reset}"
                                ECHOTRUNK=1
                        fi
                        echo "$SHELLYIP ($SHELLYTYPE) ${yellow}Update von v$OLDFIRMWARE auf Version ${cyan}v$NEWFIRMWARE ${yellow}vorhanden${reset}."
                        if [ $UPDATE = "BETA" ] ; then
                                NEWFIRMWAREURL=$(curl -s https://repo.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].beta_url' | cut -d '"' -f2)
                                NEWFIRMWAREFULL=$STABLENEWFIRMWAREFULL
                        elif [ $UPDATE = "PRE" ] ; then
                                NEWFIRMWAREURL=$(curl -s https://repo.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].url' | cut -d '"' -f2)
                                NEWFIRMWAREFULL=$PRENEWFIRMWAREFULL
                        else
                                NEWFIRMWAREURL=$(curl -s https://api.shelly.cloud/files/firmware | jq '.data["'$SHELLYTYPE'"].url' | cut -d '"' -f2)
                        fi
                        NEWFIRMWAREZIP=$(echo $NEWFIRMWAREFULL | cut -d '/' -f2)
#### download firmware to server or skip if it is already there ####
                        if [ -f $WWWDIR/$SHELLYTYPE-$NEWFIRMWAREZIP.zip ] ; then
                                echo "Firmware-Datei bereits vorhanden, überspringe Download"
                        else
                                echo "Lade Firmware-Datei (v$NEWFIRMWARE) für $SHELLYTYP herunter."
                                curl -s $NEWFIRMWAREURL --output $WWWDIR/$SHELLYTYPE-$NEWFIRMWAREZIP.zip
                        fi
#### send firmware update to shelly ####
                        echo "Starte Firmware-Update bei $SHELLYIP ($SHELLYTYPE) "
                        curl -s http://$USER:$PW@$SHELLYIP/ota?url=$WWWURL/$SHELLYTYPE-$NEWFIRMWAREZIP.zip > /dev/null 2>&1
                else
                        echo "$SHELLYIP ($SHELLYTYPE) ist ${green}up-to-date${reset} (v$OLDFIRMWARE)."
                fi
        else
                echo "${red}Für $SHELLYIP konnte keine Firmware-Information abgerufen werden.${reset}"
        fi
done
