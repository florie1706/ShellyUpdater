#!/bin/bash
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
#  Florie1706, 2021
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

set -eu

#### version ####
VERSION="0.7"

#### set colors for colorised output ####
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

TRUNK=STABLE
FORCE=0
DEBUG=0
USER=admin
PW=
WWWDIR=
WWWURL=
SINGLEIP=
ECHOTRUNK=0
REPOSTABLE="https://api.shelly.cloud/files/firmware"
REPOPRE="https://api.shelly.cloud/files/firmware"
REPOBETA="https://api.shelly.cloud/files/firmware"

#### www directory where update file will be stored to use it for local ota ####
WWWDIR=/tmp
WWWURL=http://192.0.0.0

print_usage()
{
echo "Usage: $(basename $0) -p=PASSWORD [-u=USER|-sip=IP|-st=TYPE|-t=TRUNK|
--force|--debug|--h]"
}

print_help()
{
    cat << EOF

Options:
  -u, --user=USER            enter USER for authentification, standard = admin
  -p, --password=PASSWORD    enter PASSWORD for authentification
  -sip, --shelly-ip=IP       Just check/upgrade one single shelly by IP
  -st, --shelly-type=TYPE    Just check/upgrade one specific TYPE of shellies
  -t, --trunk=TRUNK          select trunk (STABLE, PRE or BETA)
  --force                    Force downgrade to selected trunk version
  --debug                    Show debug log of this script.
  -h, --help                 Prints this message
EOF
}

while [ -n "${1+x}" ]; do
    PARAM="$1"
    ARG="${2+}"
    shift
    case ${PARAM} in
        *-*=*)
            ARG=${PARAM#*=}
            PARAM=${PARAM%%=*}
            set -- "----noarg=${PARAM}" "$@"
    esac
    case ${PARAM} in
        *-help|-h)
            print_help
            exit 0
            ;;
        *-user|-u)
            USER="$ARG"
            shift
            ;;
        *-password|-p)
            PW="$ARG"
            shift
            ;;
        *-shelly-ip|-sip)
            SINGLEIP="$ARG"
            shift
            ;;
        *-shelly-type|-st)
            SHELLYTYPEARG="$ARG"
            echo "Diese Funktion ist noch nicht eingebaut!"
            exit 1
            shift
            ;;
        *-trunk|-t)
            TRUNK="$ARG"
                if [ "$ARG" != "BETA" ] && [ "$ARG" != "PRE" ]; then
                        TRUNK=STABLE
                else
                        TRUNK="$ARG"
                fi
            shift
            ;;
        *-force)
            FORCE=1
#            shift
            ;;
        *-debug)
            set -eux
            ;;
        ----noarg)
            echo "$ARG does not take an argument"
            exit
            ;;
        -*)
            echo "$PARAM" ist eine unbekannte Option, breche ab.
            exit 1
            ;;
        *)
            print_help
            exit 1
            ;;
    esac
done

#### generate shelly login credicals ####
AUTH=$(echo -n "$USER:$PW" | base64)

#### show script and trunk details ####
echo "${yellow}ShellyUpdater Version $VERSION${reset}"
echo "${yellow}$TRUNK-Kanal wurde ausgewählt.${reset}"	   

#### check for availible shellies in your network ####
if [ -z $SINGLEIP ] ; then
        SELECTION=$(avahi-browse -d local -k -v -t -r -p _http._tcp | grep helly | cut -d ';' -f8 | awk '{ print length(), $0 | "sort -n" }' | cut -d ' ' -f2)
else
        SELECTION=$SINGLEIP
fi

for SHELLYIP in $SELECTION
        do
        UPDATE=0
        OLDFIRMWAREAUTHTEST=$(curl -s --header "Authorization: Basic $AUTH" http://$SHELLYIP/settings | grep 'Unauthorized' | cut -d ' ' -f2)
        if [ -z $OLDFIRMWAREAUTHTEST ] ; then
                SHELLYTYPE=$(curl -s --header "Authorization: Basic $AUTH" http://$SHELLYIP/settings | jq .device.type | cut -d '"' -f2)
                SHELLYNAME=$(curl -s --header "Authorization: Basic $AUTH" http://$SHELLYIP/settings | jq .name)
                if [[ $SHELLYNAME = "null" ]] ; then
                        SHELLYNAME=""
                fi
                OLDFIRMWAREFULL=$(curl -s --header "Authorization: Basic $AUTH" http://$SHELLYIP/settings | jq .fw | cut -d '"' -f2)
                OLDFIRMWARE=$(echo $OLDFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
        else
                OLDFIRMWARE=""
        fi																					   
																	 
#### if no firmware version or shelly type is determinated an error message will be shown ####
        if [ -n "$OLDFIRMWARE" ] && [ -n "$SHELLYTYPE" ] ; then
#### check for newer firmware availible ####
                OLDFIRMWAREDATETIME=$(echo $OLDFIRMWAREFULL | cut -d '/' -f1 | sed 's/-//g')
                STABLENEWFIRMWAREFULL=$(curl -s $REPOSTABLE | jq '.data["'$SHELLYTYPE'"].version' | cut -d '"' -f2)
                STABLENEWFIRMWARE=$(echo $STABLENEWFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
                STABLENEWFIRMWAREDATETIME=$(echo $STABLENEWFIRMWAREFULL | cut -d '/' -f1 | sed 's/-//g')
                if [ $TRUNK = "BETA" ] ; then
                        BETANEWFIRMWAREFULL=$(curl -s $REPOBETA | jq '.data["'$SHELLYTYPE'"].beta_ver' | cut -d '"' -f2)											
                        BETANEWFIRMWARE=$(echo $BETANEWFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
                        BETANEWFIRMWAREDATETIME=$(echo $BETANEWFIRMWAREFULL | cut -d '/' -f1 | sed 's/-//g')
                        if [[ $BETANEWFIRMWAREDATETIME = "null" ]] ; then
                                BETANEWFIRMWAREDATETIME=0
			        echo "${red}Konnte keine BETA-Firmware finden.${reset}"	  
                        fi
                else
                        BETANEWFIRMWAREDATETIME=0
                fi
                if [ $TRUNK != "STABLE" ] ; then
                        PRENEWFIRMWAREFULL=$(curl -s $REPOPRE | jq '.data["'$SHELLYTYPE'"].version' | cut -d '"' -f2)
                        PRENEWFIRMWARE=$(echo $PRENEWFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)																			
                        PRENEWFIRMWAREDATETIME=$(echo $PRENEWFIRMWAREFULL | cut -d '/' -f1 | sed 's/-//g')
                        if [[ $PRENEWFIRMWAREDATETIME = "null" ]] ; then
                                PRENEWFIRMWAREDATETIME=0
                                echo "${red}Konnte keine PRE-Firmware finden.${reset}"
                        fi
                else
                        PRENEWFIRMWAREDATETIME=0
                fi
                if [ $STABLENEWFIRMWAREDATETIME -gt $PRENEWFIRMWAREDATETIME ] || [ $STABLENEWFIRMWAREDATETIME -gt $BETANEWFIRMWAREDATETIME ] || [ $TRUNK = "STABLE" ]; then
                        NEWFIRMWAREFULL=$STABLENEWFIRMWAREFULL
                        NEWFIRMWAREURL=$(curl -s $REPOSTABLE | jq '.data["'$SHELLYTYPE'"].url' | cut -d '"' -f2)
                        NEWFIRMWAREDATETIME=$STABLENEWFIRMWAREDATETIME
                        UPDATE="STABLE"
                elif [ $PRENEWFIRMWAREDATETIME -gt $BETANEWFIRMWAREDATETIME ] || [ $TRUNK = "PRE" ]; then
                        NEWFIRMWAREFULL=$PRENEWFIRMWAREFULL
                        NEWFIRMWAREURL=$(curl -s $REPOPRE | jq '.data["'$SHELLYTYPE'"].url' | cut -d '"' -f2)
                        NEWFIRMWAREDATETIME=$PRENEWFIRMWAREDATETIME
                        UPDATE="PRE"
                else
                        NEWFIRMWAREFULL=$BETANEWFIRMWAREFULL
                        NEWFIRMWAREURL=$(curl -s $REPOBETA | jq '.data["'$SHELLYTYPE'"].beta_url' | cut -d '"' -f2)
                        NEWFIRMWAREDATETIME=$BETANEWFIRMWAREDATETIME
                        UPDATE="BETA"
                fi
#### check if newer version is availible and if there is a newer version then your choosen trunk on STABLE/PRE when PRE/BETA was selected) for new shipped devices the current firmware will be installed ####
                if [ $NEWFIRMWAREDATETIME -gt $OLDFIRMWAREDATETIME ] || { [ $FORCE = 1 ] && [ $NEWFIRMWAREDATETIME -ne $OLDFIRMWAREDATETIME ]; }; then
                        if [ $ECHOTRUNK -eq 0 ] && [ $UPDATE != $TRUNK ]; then
                                echo "${yellow}$UPDATE-Kanal hat neuere Firmware, $UPDATE wird nun verwendet.${reset}"
                                ECHOTRUNK=1
                        fi
                        NEWFIRMWAREZIP=$(echo $NEWFIRMWAREFULL | cut -d '/' -f2)
                        NEWFIRMWARE=$(echo $NEWFIRMWAREFULL | cut -d 'v' -f2 | cut -d '@' -f1 | cut -d '-' -f1)
                        echo "$SHELLYIP ($SHELLYTYPE) ${yellow}Update von v$OLDFIRMWARE auf Version ${cyan}v$NEWFIRMWARE ${yellow}vorhanden${reset}."
#### download firmware to server or skip if it is already there ####
                        if [ -f $WWWDIR/$SHELLYTYPE-$NEWFIRMWAREZIP.zip ] ; then
                                echo "Firmware-Datei bereits vorhanden, überspringe Download"
                        else
                                echo "Lade Firmware-Datei (v$NEWFIRMWARE) für $SHELLYTYPE herunter."
                                curl -s $NEWFIRMWAREURL --output $WWWDIR/$SHELLYTYPE-$NEWFIRMWAREZIP.zip
                        fi
#### send firmware update to shelly ####
                        echo "Starte Firmware-Update bei $SHELLYIP ($SHELLYTYPE) "
                        curl -s --header "Authorization: Basic $AUTH" http://$SHELLYIP/ota?url=$WWWURL/$SHELLYTYPE-$NEWFIRMWAREZIP.zip > /dev/null 2>&1
                else
                        echo "$SHELLYIP - $SHELLYNAME ($SHELLYTYPE) ist ${green}up-to-date${reset} (v$OLDFIRMWARE)."
                fi
        else
                echo "${red}Für $SHELLYIP konnte keine Firmware-Information abgerufen werden.${reset}"
        fi
done
