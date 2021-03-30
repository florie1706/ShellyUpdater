ShellyUpdater

Update your shelly devices thru this script.
Tested on Ubuntu 20.04 with a 192.-Network.

##You will need the following packages to be installed in advance:
```
- avahi-utils
- jq
- webserver (which is running to serve the OTA-zip file for the firmware update)
```

## Please set these variables first:
```
- WWWDIR where the firmware update has to be stored
- WWWURL URL where your webserver can be reached from any device within your network
```

## Call the script with one or more of theses arguments:

```
-u, --user=USER            enter USER for authentification, standard = admin
-p, --password=PASSWORD    enter PASSWORD for authentification
-sip, --shelly-ip=IP       Just check/upgrade one single shelly by IP
-st, --shelly-type=TYPE    Just check/upgrade one specific TYPE of shellies
-t, --trunk=TRUNK          select trunk (STABLE, PRE or BETA)
--force                    Force downgrade to selected trunk version
--debug                    Show debug log of this script.
-h, --help                 Prints this message
```

Florie1706, 2021
