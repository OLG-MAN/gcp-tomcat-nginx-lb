#!/bin/bash

# Install nginx
sudo apt update 
sudo apt install -y nginx
sudo systemctl enable nginx
sudo chmod 755 /var/www/html/index.nginx-debian.html

# Add content to site
curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" > /var/www/html/index.nginx-debian.html
echo '<br>' >> /var/www/html/index.nginx-debian.html
curl "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google" >> /var/www/html/index.nginx-debian.html
echo '<br>' >> /var/www/html/index.nginx-debian.html
curl 2ip.me >> /var/www/html/index.nginx-debian.html
sudo systemctl restart nginx

# Install fluentd agent
sudo curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
sudo bash add-logging-agent-repo.sh --also-install
sudo service google-fluentd restart