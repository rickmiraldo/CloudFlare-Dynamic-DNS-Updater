# CloudFlare-Dynamic-DNS-Updater
Dynamically update your DNS record with CloudFlare. Updated for Cloudflare API v4. Simple usage with Raspberry Pi.


## Disclaimer / Important Information
The original script is NOT mine. I was unable to find the original author on Github. I got a forked version from the user MyLesGray from his website https://blah.cloud/networks/raspberry-pi-dynamic-dns-using-cloudflare/ but it was written using CloudFlare's v1 API which will be retired on June 4th 2018. Without prior knowledge of bash scripts I decided to study the CloudFlare v4 API and update the script accordingly by myself. This is the end result, which is working fine for me in a Raspberry Pi, but I haven't tested it in every possible scenario. YMMV.

## Initial setup
Download the script manually or with wget. Make it executable with chmod. Next, edit it with nano, vim or whatever you prefer. Fill in the following parameters:

```
# API key, see https://www.cloudflare.com/a/account/my-account,
# incorrect api-key results in E_UNAUTH error
CFKEY=

# Zone name, will list all possible if missing, eg: example.com
CFZONE=

# Username, eg: user@example.com
CFUSER=

# Hostname to update, eg: homeserver.example.com
CFHOST=
```

Save and run the script. If all goes well you might get a message advising you to save the CFID it found to the file. Edit it again and fill in the corresponding parameter. All done!

Optionally, add the following line to crontab so that the script executes automatically every 2 minutes (or whenever you prefer):

```
*/2 * * * * /path/to/file/cf-ddns-v4.sh >/dev/null 2>&1
```

Enjoy!
