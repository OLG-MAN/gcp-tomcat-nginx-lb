#!/bin/bash

# Install nginx
sudo su <<HERE
apt update 
apt install -y nginx
systemctl enable nginx

# Setup conf file
cat << EOF > /etc/nginx/nginx.conf
events {}

http {
    server {
        listen 80;

        location / {
            proxy_pass 'http://10.1.2.99:8080/';
            proxy_http_version 1.1;
        }

        location /demo {
            proxy_pass 'http://10.1.2.99:8080/sample';
            proxy_http_version 1.1;
        }

        location /img {
            proxy_pass 'https://storage.googleapis.com/nginx-bucket12/101.png';
        }
    }
}
EOF
service nginx restart
HERE

# Add content to site
# sudo chmod 755 /var/www/html/index.nginx-debian.html
# curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" > /var/www/html/index.nginx-debian.html
# echo '<br>' >> /var/www/html/index.nginx-debian.html
# curl "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google" >> /var/www/html/index.nginx-debian.html
# echo '<br>' >> /var/www/html/index.nginx-debian.html
# curl 2ip.me >> /var/www/html/index.nginx-debian.html
# sudo systemctl restart nginx


# Install fluentd agent
# curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
# bash add-logging-agent-repo.sh --also-install
# service google-fluentd restart