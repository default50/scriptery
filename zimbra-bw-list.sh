#!/bin/bash

# Script to add and remove mail accounts from Amavis whitelist and blacklist under Zimbra

# Author: Sebastian Cruz <default50@gmail.com>

PATH=$PATH:/opt/zimbra/bin

if [ $UID != 0 ]; then
        echo "You must be root to run this script."
        exit 1
fi

list_per_domain() {
        zmprov gad | while read domain; do echo "Domain $domain:"; zmprov gd $domain | grep -E "Whitelist|Blacklist"; done
}

addBlacklist() {
        zmprov gad | while read lig; do zmprov md $lig +amavisBlacklistSender $1; done
}

addWhitelist() {
        zmprov gad | while read lig; do zmprov md $lig +amavisWhitelistSender $1; done
}

delBlacklist() {
        zmprov gad | while read lig; do zmprov md $lig -amavisBlacklistSender $1; done
}

delWhitelist() {
        zmprov gad | while read lig; do zmprov md $lig -amavisWhitelistSender $1; done
}


case $1 in
        list)
                list_per_domain ;;
        +blacklist)
                addBlacklist $2 ;;
        +whitelist)
                addWhitelist $2 ;;
        -blacklist)
                delBlacklist $2 ;;
        -whitelist)
                delWhitelist $2 ;;
        *)
                echo "Usage: $0 [list] [[+|-]blacklist \"mail@domain.pp\"] [[+|-]whitelist \"mail@domain.pp\"]" ;;
esac
