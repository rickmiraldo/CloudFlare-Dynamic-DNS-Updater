#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Automatically update your CloudFlare DNS record to the IP, Dynamic DNS
# Can retrieve cloudflare Domain id and list zone's, because, lazy

# Place at:
# /usr/local/bin/cf-ddns.sh
# run `crontab -e` and add next line:
# 0 * * * * /usr/local/bin/cf-ddns.sh >/dev/null 2>&1
# run /usr/local/bin/cf-ddns.sh in terminal to check all settings are valid

# Usage:
# cf-ddns.sh -k cloudflare-api-key \
#            -u user@example.com \
#            -h host.example.com \     # fqdn of the record you want to update
#            -z example.com \          # will show you all zones if forgot, but you need this

# Optional flags:
#            -i cloudflare-record-id \ # script will show this
#            -a true|false \           # auto get zone list and record id
#            -f false|true \           # force dns update, disregard local stored ip

# default config

# API key, see https://www.cloudflare.com/a/account/my-account,
# incorrect api-key results in E_UNAUTH error
CFKEY=

# Zone name, will list all possible if missing, eg: example.com
CFZONE=

# Domain id, will retrieve itself by default
CFID=

# Username, eg: user@example.com
CFUSER=

# Hostname to update, eg: homeserver.example.com
CFHOST=

# Cloudflare TTL for record, between 120 and 86400 seconds
CFTTL=3600
# Get domain ID from Cloudflare using awk/sed and python json.tool
GETID=true
# Ignore local file, update ip anyway
FORCE=false
# Site to retrieve WAN ip, other examples are: bot.whatismyipaddress.com, https://api.ipify.org/ ...
WANIPSITE="http://icanhazip.com"

# get parameter
while getopts a:k:i:u:h:z:f: opts; do
  case ${opts} in
    a) GETID=${OPTARG} ;;
    k) CFKEY=${OPTARG} ;;
    i) CFID=${OPTARG} ;;
    u) CFUSER=${OPTARG} ;;
    h) CFHOST=${OPTARG} ;;
    z) CFZONE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
  esac
done

# If required settings are missing just exit
if [ "$CFKEY" = "" ]; then
  echo "Missing api-key, get at: https://www.cloudflare.com/a/account/my-account"
  echo "and save in ${0} or using the -k flag"
  exit 2
fi
if [ "$CFUSER" = "" ]; then
  echo "Missing username, probably your email-address"
  echo "and save in ${0} or using the -u flag"
  exit 2
fi
if [ "$CFHOST" = "" ]; then 
  echo "Missing hostname, what host do you want to update?"
  echo "save in ${0} or using the -h flag"
  exit 2
fi

# If the hostname is not a FQDN
if [ "$CFHOST" != "$CFZONE" ] && ! [ -z "${CFHOST##*$CFZONE}" ]; then
  CFHOST="$CFHOST.$CFZONE"
  echo " => Hostname is not a FQDN, assuming $CFHOST"
fi

# If CFZONE is missing, retrieve them all from CF
if [ "$CFZONE" = "" ]; then
  echo "Missing zone"
  if ! [ "$GETID" == true ]; then exit 2; fi
  echo "listing all zones: (if api-key is valid)"
  curl -s -X GET https://api.cloudflare.com/client/v4'/zones' \
    -H 'X-Auth-Email: '$CFUSER \
	-H 'X-Auth-Key: '$CFKEY \
	-H 'Content-Type: application/json' \
    | grep -Eo '"name":"([^"]+)"' \
    | cut -d':' -f2 \
    | awk '{gsub("\"","");print "* "$1}' \
    | head -1
  echo "Please specify the matching zone in ${0} or specify using the -z flag"
  exit 2
fi

# Get current and old WAN ip
WAN_IP=`curl -s ${WANIPSITE}`
if [ -f $HOME/.wan_ip-cf.txt ]; then
  OLD_WAN_IP=`cat $HOME/.wan_ip-cf.txt`
else
  echo "No file, need IP"
  OLD_WAN_IP=""
fi

# If WAN IP is unchanged an not -f flag, exit here
if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
  echo "WAN IP Unchanged, to update anyway use flag -f true"
  exit 0
fi

# If CFID is missing retrieve and use it
if [ "$CFID" = "" ]; then
  echo "Missing DNS record ID"
  if ! [ "$GETID" == true ]; then exit 2; fi
  echo "fetching from Cloudflare..."
  ZONEID=$(
  curl -s -X GET https://api.cloudflare.com/client/v4'/zones' \
    -H 'X-Auth-Email: '$CFUSER \
	-H 'X-Auth-Key: '$CFKEY \
	-H 'Content-Type: application/json' \
    | grep -Eo '"id":"([^"]+)"' \
    | cut -d':' -f2 \
    | awk '{gsub("\"","");print $1}' \
    | head -1
  );
  if ! CFID=$(
  curl -s -X GET https://api.cloudflare.com/client/v4'/zones/'$ZONEID'/dns_records?type=A&name='$CFHOST'' \
    -H 'X-Auth-Email: '$CFUSER \
    -H 'X-Auth-Key: '$CFKEY \
    -H 'Content-Type: application/json' \
    | grep -Eo '"(id)":"([^"]+)"' \
    | cut -d':' -f2 \
    | awk '{gsub("\"","");print $1}'
  ); then
    echo " => Incorrect zone, or zone doesn't contain the A-record ${CFHOST}!"
    echo "listing all records for zone ${CFZONE}:"
    (printf "ID TYPE RECORD\n";
    curl -s -X GET https://api.cloudflare.com/client/v4'/zones/'$ZONEID'/dns_records' \
      -H 'X-Auth-Email: '$CFUSER \
      -H 'X-Auth-Key: '$CFKEY \
      -H 'Content-Type: application/json' \
      | grep -Eo '"(id|name|type)":"([^"]+)"' \
      | cut -d':' -f2 \
      | awk 'NR%3{gsub("\"","");printf $0" ";next;}1'
    )| column -t
    exit 2
  fi
  echo " => Found CFID=${CFID}, advising to save this to ${0} or set it using the -i flag"
fi

# If WAN is changed, update cloudflare
echo "Updating DNS to $WAN_IP"
ZONEID=$(
  curl -s -X GET https://api.cloudflare.com/client/v4'/zones' \
    -H 'X-Auth-Email: '$CFUSER \
	-H 'X-Auth-Key: '$CFKEY \
	-H 'Content-Type: application/json' \
    | grep -Eo '"id":"([^"]+)"' \
    | cut -d':' -f2 \
    | awk '{gsub("\"","");print $1}' \
    | head -1
  );
RESPONSE=$(
curl -s -X PUT https://api.cloudflare.com/client/v4'/zones/'$ZONEID'/dns_records/'$CFID'' \
  -H 'X-Auth-Email: '$CFUSER \
  -H 'X-Auth-Key: '$CFKEY \
  -H 'Content-Type: application/json' \
  --data '{
      "type": "A",
      "name": "'$CFHOST'",
      "content": "'$WAN_IP'",
      "ttl": '$CFTTL'
  }'
) 
if [ "$RESPONSE" != "${RESPONSE%true*}" ]; then
  echo "Updated succesfuly!"
  echo $WAN_IP > $HOME/.wan_ip-cf.txt
  exit
else
  echo 'Something went wrong :('
  echo "Response: $RESPONSE"
  exit 1
fi
