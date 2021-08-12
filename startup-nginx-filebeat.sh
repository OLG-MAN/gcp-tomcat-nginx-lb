#!/bin/bash

# Install nginx
sudo su <<HERE
apt update 
apt install -y nginx
systemctl enable nginx


# Configure /etc/nginx/sites-available/default file
gsutil cp gs://nginx-bucket1/default /etc/nginx/sites-available
service nginx restart


# Change content on Nginx main page.
chmod 755 /var/www/html/index.nginx-debian.html
echo '<h1>' > /var/www/html/index.nginx-debian.html
echo '<p>This is Frontend</p>' >> /var/www/html/index.nginx-debian.html
curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" >> /var/www/html/index.nginx-debian.html
echo '<br>' >> /var/www/html/index.nginx-debian.html
curl "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google" >> /var/www/html/index.nginx-debian.html
echo '<br>' >> /var/www/html/index.nginx-debian.html
curl 2ip.me >> /var/www/html/index.nginx-debian.html
echo '</h1>' >> /var/www/html/index.nginx-debian.html
systemctl restart nginx


# Install Filebeat agent for logs exporting.
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.14.0-amd64.deb
sudo dpkg -i filebeat-7.14.0-amd64.deb

# Copy prepared configuration file
gsutil cp gs://nginx-bucket1/filebeat.yml /etc/filebeat/

# Enable modules and start agent
filebeat modules enable system
filebeat modules enable nginx
filebeat setup
service filebeat start
HERE