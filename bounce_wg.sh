#!/usr/bin/env bash
set -e

# Bring up Wireguard interface
#   This script checks to see if the wireguard interface is down, and if
#   it is, it attempts to bring it back up. It is intended primarily to be
#   called from a cron job.
#
# Writen by Larry Gadallah

VERSION="v0.02"

E_NOTFOUND=127

PROG="$(basename "${0}" .sh)"
LOCKFILE="/tmp/.${PROG}.lock"

LOGGER="$(command -v logger)"
WG="$(command -v wg)"
WG_QUICK="$(command -v wg-quick)"
IP_CMD="$(command -v ip)"

WG_IF="${1:-wg0}"  # Wireguard interface name

LogMsg()
{
  "${LOGGER}" -t "${PROG}(${VERSION})" -i -p daemon.info "${1}"
}

CheckEnvironment()
{
  if [ -z "${LOGGER}" ]; then
      >&2 echo "logger binary is not installed, or is not in \$PATH"
      exit "${E_NOTFOUND}"
  fi

  if [ -z "${WG}" ]; then
      LogMsg "wg binary is not installed, or is not in \$PATH"
      exit "${E_NOTFOUND}"
  fi

  if [ -z "${WG_QUICK}" ]; then
      LogMsg "wg-quick binary is not installed, or is not in \$PATH"
      exit "${E_NOTFOUND}"
  fi

  if [ -z "${IP_CMD}" ]; then
      LogMsg "ip binary is not installed, or is not in \$PATH"
      exit "${E_NOTFOUND}"
  fi
}

GetLock()
{
  set -C
  if (echo "$$" > "${LOCKFILE}") 2> /dev/null ; then
    trap 'rm -fr "${LOCKFILE}"' 0 SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGBUS SIGFPE
  else
    LogMsg "Unable to get lockfile, already locked by $(cat "${LOCKFILE}")"
    exit 1
  fi
}

GetLock
CheckEnvironment

if [ 1 -eq 0 ] ; then
   ## (BG) The following does NOT detect a DOWN WireGuard interface
   if "${IP_CMD}" link show "${WG_IF}" up type wireguard > /dev/null 2>&1 ; then
       LogMsg "$("${WG}" show "${WG_IF}" | tr -d '\n')"
   else
      # restart wireguard link if it is down
      LogMsg "$("${WG_QUICK}" up "${WG_IF}" | tr -d '\n')"
    fi
fi

## (BG) The following DOES detect a DOWN WireGuard interface
link_state="$(ip link show $WG_IF |  grep -oP '(?<=state )[^ ]*')"
if [ "$link_state" = "DOWN" ] ; then
    LogMsg "WireGuard interface is DOWN: $("${WG}" show ${WG_IF})"
    # Restart the Wire Guard interface
    # First bring the interface down
    ${WG_QUICK} down ${WG_IF}

    #Then bring the interface up
    ${WG_QUICK} up ${WG_IF}
    LogMsg "WireGuard interface wg status 1 after down/up: $("${WG}" show ${WG_IF})"
    LogMsg "WireGuard interface link status 2 after down/up: $(ip link show $WG_IF)"
else
    # Wire Guard insterface is UP so just put something in the log file
    # to confirm things are working.
    LogMsg "$("${WG}" show "${WG_IF}" | tr -d '\n')"
fi