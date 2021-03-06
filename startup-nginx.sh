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


# Install fluentd agent for logs exporting to Bigquery
curl -L https://toolbelt.treasuredata.com/sh/install-debian-buster-td-agent4.sh | sh
usermod -aG adm td-agent
/usr/sbin/td-agent-gem install fluent-plugin-bigquery


# Configure .conf file connect to BigQuery
cat << EOF >> /etc/td-agent/td-agent.conf
<source>
  @type tail
  @id input_tail
  <parse>
    @type nginx
  </parse>
  path /var/log/nginx/access.log
  pos_file /var/log/td-agent/httpd-access.log.pos
  tag nginx.access
</source>

<match nginx.access>
  @type bigquery_insert

  # Authenticate with BigQuery using the VM's service account.
  auth_method compute_engine
  project tomcat-nginx-lb
  dataset fluentd
  table nginx_access
  fetch_schema true

  <inject>
    # Convert fluentd timestamp into TIMESTAMP string
    time_key time
    time_type string
    time_format %Y-%m-%dT%H:%M:%S.%NZ
  </inject>
</match>
EOF
service td-agent restart
HERE

# Install fluentd agent option 2
# curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
# bash add-logging-agent-repo.sh --also-install
# service google-fluentd restart