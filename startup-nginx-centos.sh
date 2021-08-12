#!/bin/bash

# Install nginx
sudo su <<HERE
yum update -y
yum install nginx -y
systemctl start nginx
systemctl enable nginx

# Change content on Nginx main page.
chmod 755 /usr/share/nginx/html/index.html
echo '<h1>' > /usr/share/nginx/html/index.html
echo '<p>This is Frontend</p>' >> /usr/share/nginx/html/index.html
curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" >> /usr/share/nginx/html/index.html
echo '<br>' >> /usr/share/nginx/html/index.html
curl "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google" >> /usr/share/nginx/html/index.html
echo '<br>' >> /usr/share/nginx/html/index.html
curl 2ip.me >> /usr/share/nginx/html/index.html
echo '</h1>' >> /usr/share/nginx/html/index.html
systemctl restart nginx

# Install and Configure Filebeat agent
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.14.0-x86_64.rpm
sudo rpm -vi filebeat-7.14.0-x86_64.rpm

# Copy prepared configuration file
gsutil cp gs://nginx-bucket1/filebeat.yml /etc/filebeat/

# Enable modules and start agent
filebeat modules enable system
filebeat modules enable nginx
filebeat setup
service filebeat start
HERE