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

#Install and Configure Filebeat agent


HERE