#!/bin/bash

# Install java and tomcat, configure user for tomcat
sudo su <<HERE
apt update
apt install wget -y
apt install default-jdk -y
useradd -m -U -d /opt/tomcat -s /bin/false tomcat
wget https://downloads.apache.org/tomcat/tomcat-10/v10.0.8/bin/apache-tomcat-10.0.8.tar.gz
tar -zxvf apache-tomcat-*.tar.gz -C /opt/tomcat --strip-components=1
chown tomcat:tomcat /opt/tomcat/ -R
chmod u+x /opt/tomcat/bin -R


# Systemd Config tomcat.service
cat << EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat
Wants=network.target
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64/
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1G -Djava.net.preferIPv4Stack=true'
Environment='JAVA_OPTS=-Djava.awt.headless=true'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
SuccessExitStatus=143

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF


# Edit tomcat-users.xml
cat << EOF > /opt/tomcat/conf/tomcat-users.xml
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
<role rolename="admin-gui, manager-gui" />
<user username="admin" password="admin" roles="manager-gui,admin-gui"/>
</tomcat-users>
EOF


# Editing remote access to manager (Server-status, manager app)
cat << EOF > /opt/tomcat/webapps/manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1|.*" />
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF


# Editing remote access to host-manager
cat << EOF > /opt/tomcat/webapps/host-manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1|.*" />
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF


# Restart daemon and start service
systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat


# Install app.
gsutil cp gs://tomcat-bucket1/sample.war .
mv sample.war /opt/tomcat/webapps
systemctl restart tomcat
HERE