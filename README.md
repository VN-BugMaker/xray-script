## Installation VLESS-XTLS-uTLS-REALITY
```
 bash -c "$(curl -L https://raw.githubusercontent.com/VN-BugMaker/xray-script/main/install_xray_reality.sh)"
```

## DDNS Cloudflare
```
 curl -o /root/cloudflare_ddns.sh https://raw.githubusercontent.com/VN-BugMaker/xray-script/main/cloudflare_ddns.sh
```
```
 crontab -e
```
```
 ### Add the code below to update every 30 seconds
 * * * * * /root/cloudflare_ddns.sh
 * * * * * sleep 30 ; /root/cloudflare_ddns.sh
```
```
 sudo /etc/init.d/cron restart
```
