## Task_1
### [TASK 2](https://github.com/OLG-MAN/tomcat-nginx-lb#Task_2)
### [TASK 3](https://github.com/OLG-MAN/tomcat-nginx-lb#Task_3)
### Tomcat(backend) and Nginx(frontend) in MIGs with LB.

### Task goals

1. Create bucket for Tomcat application files and another one for static web files (think about permissions).
2. Create MIG for backend with installed tomcat and on boot download demo application from bucket. Setup autoscaling by CPU (think about scale down).
3. Create bucket for Nginx application files and another one for static web files (think about permissions).
4. Add one more MIG for frontend with nginx, by path /demo/ show demo app from bucket, by path /img/picture.jpg show file from bucket.
5. Create LB for tomcat and nginx.
6. Setup export of nginx logs to bucket/BigQuery.

## Solution using Cloud Shell

## 0. 

### Configuring Network for tasks

* #### Delete default VPC. Make new VPC with 2 subnets (for backend and for proxy(int-lb))

```
gcloud compute networks delete default

gcloud compute networks create lb-network --subnet-mode=custom

gcloud compute networks subnets create backend-subnet \
--network=lb-network \
--range=10.1.2.0/24 \
--region=us-west1

gcloud compute networks subnets create proxy-only-subnet \
--purpose=INTERNAL_HTTPS_LOAD_BALANCER \
--role=ACTIVE \
--region=us-west1 \
--network=lb-network \
--range=10.129.0.0/23
```

* #### Configuring Firewall rules

```
gcloud compute firewall-rules create fw-allow-ssh \
--network=lb-network \
--action=allow \
--direction=ingress \
--target-tags=allow-ssh \
--rules=tcp:22

gcloud compute firewall-rules create fw-allow-http \
--network=lb-network \
--action=allow \
--direction=ingress \
--target-tags=allow-http \
--rules=tcp:80,8080

gcloud compute firewall-rules create fw-allow-health-check \
--network=lb-network \
--action=allow \
--direction=ingress \
--source-ranges=130.211.0.0/22,35.191.0.0/16 \
--target-tags=load-balanced-backend \
--rules=tcp

gcloud compute firewall-rules create fw-allow-proxies \
--network=lb-network \
--action=allow \
--direction=ingress \
--source-ranges=source-range \
--target-tags=load-balanced-backend \
--rules=tcp:80,tcp:443,tcp:8080
```

-----------------------------------------------------

## 1. 

* #### Making buckets for tomcat through 'gsutil'. 

```
gsutil mb gs://tomcat-bucket1
gsutil cp startup-tomcat.sh gs://tomcat-bucket1
gsutil cp sample.war gs://tomcat-bucket1
```


-------------------------------------------------------------

## 2. 

* #### Create instance template for tomcat MIG with startup script from bucket. (using startup-tomcat.sh file in repo)

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create instance-template-tomcat-1 \
--machine-type=e2-medium \
--subnet=projects/tomcat-nginx-lb/regions/us-west1/subnetworks/backend-subnet \
--network-tier=PREMIUM \
--metadata=startup-script-url=gs://tomcat-bucket1/startup-tomcat.sh \
--region=us-west1 \
--tags=allow-ssh,allow-http \
--image=debian-10-buster-v20210721 \
--image-project=debian-cloud \
--boot-disk-size=10GB \
--boot-disk-type=pd-balanced
```

* #### Create Managed Instance Group from tomcat instance template

```
gcloud compute --project "tomcat-nginx-lb" health-checks create http "tomcat-health-check" \
--timeout "5" \
--check-interval "10" \
--unhealthy-threshold "3" \
--healthy-threshold "2" \
--port "8080" \
--request-path "/"

gcloud beta compute --project=tomcat-nginx-lb instance-groups managed create instance-group-tomcat-1 \
--base-instance-name=instance-group-tomcat-1 \
--template=instance-template-tomcat-1 \
--size=1 \
--zone=us-west1-b \
--health-check=tomcat-health-check


gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-tomcat-1" \
--zone "us-west1-b" \
--cool-down-period "60" \
--max-num-replicas "4" \
--min-num-replicas "2" \
--target-cpu-utilization "0.8" \
--mode "on"
```
--------------------------------------------

## 3. 

* #### Making buckets for nginx through 'gsutil'. 

```
gsutil mb gs://nginx-bucket1
gsutil cp startup-nginx.sh gs://nginx-bucket1

gsutil mb gs://nginx-bucket12
gsutil cp 101.png gs://nginx-bucket12
```

* #### Make Public access for nginx-bucket12
```
gsutil iam ch allUsers:objectViewer gs://nginx-bucket12
```

-----------------------------------------------

## 4. 

* #### Create instance template for nginx MIG with startup script from bucket. (using startup-nginx.sh file in repo)

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create instance-template-nginx-1 \
--machine-type=e2-medium \
--subnet=projects/tomcat-nginx-lb/regions/us-west1/subnetworks/backend-subnet \
--network-tier=PREMIUM \
--metadata=startup-script-url=gs://nginx-bucket1/startup-nginx.sh \
--tags=allow-http,allow-ssh \
--image=debian-10-buster-v20210721 \
--image-project=debian-cloud \
--boot-disk-size=10GB \
--boot-disk-type=pd-balanced
```

* #### Create Managed Instance Group from Nginx template.

```
gcloud compute --project "tomcat-nginx-lb" health-checks create http "nginx-health-check" \
--timeout "5" \
--check-interval "10" \
--unhealthy-threshold "3" \
--healthy-threshold "2" \
--port "80" \
--request-path "/"

gcloud compute --project=tomcat-nginx-lb instance-groups managed create instance-group-nginx-1 \
--base-instance-name=instance-group-nginx-1 \
--template=instance-template-nginx-1 \
--size=1 \
--zone=us-west1-a \
--health-check=nginx-health-check


gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-nginx-1" \
--zone "us-west1-a" \
--cool-down-period "60" \
--max-num-replicas "4" \
--min-num-replicas "2" \
--target-cpu-utilization "0.8" \
--mode "on"
```

---------------------------------------------

## 5. 

* #### Making Internal LB for tomcat MIG

* #### Health check for tomcat MIG

```
gcloud compute health-checks create http tomcat-mig-check \
--region=us-west1 \
--port 8080 
```

* #### Backend Service

```
gcloud compute backend-services create tomcat-backend-service \
--load-balancing-scheme=INTERNAL_MANAGED \
--protocol=HTTP \
--health-checks=tomcat-mig-check \
--health-checks-region=us-west1 \
--region=us-west1
```

* #### Add backends to backend service

```
gcloud compute backend-services add-backend tomcat-backend-service \
--balancing-mode=UTILIZATION \
--max-utilization=0.8 \
--instance-group=instance-group-tomcat-1 \
--instance-group-zone=us-west1-b \
--region=us-west1
```
(After creating and adding backend service, need change port from 80 to 8080 manually)

* #### URL map

```
gcloud compute url-maps create tomcat-int-lb \
--default-service=tomcat-backend-service \
--region=us-west1
```

* #### Target proxy

```
gcloud compute target-http-proxies create tomcat-lb-proxy \
--url-map=tomcat-int-lb \
--url-map-region=us-west1 \
--region=us-west1
```

* #### Forwarding rule 

```
gcloud compute forwarding-rules create tomcat-forwarding-rule \
--load-balancing-scheme=INTERNAL_MANAGED \
--network=lb-network \
--subnet=backend-subnet \
--address=10.1.2.99 \
--ports=8080 \
--region=us-west1 \
--target-http-proxy=tomcat-lb-proxy \
--target-http-proxy-region=us-west1
```

------------------------------------------

* #### Extarnal LB for Nginx MIG

* #### Named port

```
gcloud compute instance-groups set-named-ports instance-group-nginx-1 \
--named-ports http:80 \
--zone us-west1-a
```

* #### Reserving an external IP address

```
gcloud compute addresses create lb-ipv4-1 \
--ip-version=IPV4 \
--global

# Describe IP

gcloud compute addresses describe lb-ipv4-1 \
--format="get(address)" \
--global
```

* #### Health check for Nginx MIG LB

```
gcloud compute health-checks create http nginx-mig-check \
--port 80
```

* #### Create Backend service

```
gcloud compute backend-services create nginx-backend-service \
--protocol=HTTP \
--port-name=http \
--health-checks=nginx-mig-check \
--global
```

* #### Add MIG to Backend service

```
gcloud compute backend-services add-backend nginx-backend-service \
--instance-group=instance-group-nginx-1 \
--instance-group-zone=us-west1-a \
--global
```

* #### URL map

```
gcloud compute url-maps create ext-nginx-lb \
--default-service nginx-backend-service
```

* #### HTTP proxy

``` 
gcloud compute target-http-proxies create http-lb-proxy \
--url-map=ext-nginx-lb
```

* #### Forwarding rules

```
gcloud compute forwarding-rules create http-content-rule \
--address=lb-ipv4-1 \
--global \
--target-http-proxy=http-lb-proxy \
--ports=80
```

### Summary

- We can go to external LB what redirected us on Nginx MiG. 
- On main page we can find Nginx Frontend page with data:

```
This is Frontend

instance-group-nginx-1-q0l2
instance-group-nginx-1-q0l2.us-west1-a.c.tomcat-nginx-lb.internal
ip : 34.105.24.253 provider : UNALLOCATED location : United States Of America (US), The Dalles
```

- Nginx MIG configured with Nginx internal LB what redirected to tomcat MIG through GCP internal LB IP address. 

- If we go to <external-LB-IP>/tomcat we being redirect to backend with tomcat admin main page.

- If we go to <external-LB-IP>/demo we being redirect to backend with tomcat sample app what pre-installed in startup script.

- If we go to <external-LB-IP>/img we being redirect to backend bucket with target image.

--------------------------------------------------

## 6.

* ### Analyzing logs, Fluentd and BigQuery

* #### Configure Fluentd.

- Agent already pre-installed and configured in startup-nginx.sh
- Important, when we creating templates give 'access anabled' to BigQuey API

* #### Configure BigQuery.

- Configure Bigquery dataset and table.

```
- Open the BigQuery web UI:

- Go to the BigQuery Web UI

- In the navigation panel, under Resources, click your project name.

- In the details panel below the Query Editor, click Create Dataset.

- For Dataset ID, enter fluentd.

- For Data Location, select the multiregional location (US or Europe) where you created the NGINX instance.

- Click Create Dataset.

- In the navigation panel, under Resources, click the fluentd dataset.

- In the details panel below the Query Editor, click Create Table.

- For the table name, enter nginx_access.

- Select the Edit as Text option.

- Copy the following JSON column definition into the text box.
```

```
[  { "type": "TIMESTAMP", "name": "time" },
   { "type": "STRING",    "name": "remote" },
   { "type": "STRING",    "name": "host" },
   { "type": "STRING",    "name": "user" },
   { "type": "STRING",    "name": "method" },
   { "type": "STRING",    "name": "path" },
   { "type": "STRING",    "name": "code" },
   { "type": "INTEGER",   "name": "size" },
   { "type": "STRING",    "name": "referer" },
   { "type": "STRING",    "name": "agent" },
   { "type": "STRING",    "name": "http_x_forwarded_for" } ]
```

References
- https://cloud.google.com/architecture/fluentd-bigquery

--------------------------------------------

* #### Simulating load and calculating statistics from the logs in Bigquery. (optional)

- #### Install the ApacheBench (ab) web server benchmarking tool.

```
sudo apt install -y apache2-utils

ab -t 20 -c 1 http://[IP_ADDRESS]/
```

- #### Get a list of ApacheBench requests using the following sample queries in the Query Editor.

```
SELECT * FROM `fluentd.nginx_access` limit 100
```

```
SELECT
  time_sec, code, COUNT(*) as count
FROM (
  SELECT
    TIMESTAMP_TRUNC(time, SECOND)AS time_sec, code
  FROM
    `fluentd.nginx_access`)
GROUP BY
  time_sec, code
ORDER BY
  time_sec DESC
```

-----------------------------------


## Task_2

### Goals

1. Install and configure Filebeat agent on MIGs for logs export.
2. MIG rolling update with changing template OS (Debian to centOS) on tomcat backend.
3. Configure internal LB that he return traffic only if target host return http 2xx code.

### Solution

### 1.

* #### Make logs export flow like in image. 

- #### From Cloud logging logs sends to Pub/Sub after this logs send to Filebeat and finally to Cloud Elastic Deployment.

![](img/5.png)

- ### Set up a Pub/Sub topic and subscriiption.

![](img/6.png)

- ### Turn on audit logging for all services.

![](img/7.png)

- ### Create a Sink service. Use this filter below.

```
logName="projects/tomcat-nginx-lb/logs/cloudaudit.googleapis.com%2Factivity" OR
"projects/tomcat-nginx-lb/logs/cloudaudit.googleapis.com%2Fdata_access" OR
"projects/tomcat-nginx-lb/logs/cloudaudit.googleapis.com%2Fsystem_event" OR
resource.type:"gce" OR resource.type="gcs_bucket" OR resource.type="bigquery_resource"
```

- ### Set IAM policy permissions for the Pub/Sub topic.
Create Service account to the "es-logs-export" Pub/Sub topic with the Pub/Sub Publisher permissions, it grant the service account permission to publish to the topic.

- ### Check that the topic is receiving messages by using the Metrics Explorer in Cloud Monitoring.

![](img/8.png)


- ### Create Elastic Cloud Deployment for connect with Filebeat and monitor logs.

![](img/9.png)

![](img/10.png)

- ### Install and configure Filebeat on target host. Connect with elastic Cloud deployment.

```
# Install on CentOS. Full script in startup-nginx-centos.sh
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.14.0-x86_64.rpm
sudo rpm -vi filebeat-7.14.0-x86_64.rpm

# Modify this string in /etc/filebeat/filebeat.yml to set the connection information for Elastic Cloud:
cloud.id: "i-o-optimized-deployment:<UID>"
cloud.auth: "elastic:<password>"

sudo filebeat modules enable system
sudo filebeat modules enable nginx

sudo filebeat setup
sudo service filebeat start
```

- ### Monitring Dashboard with system and nginx modules. 

![](img/11.png)

![](img/12.png)

* ### References 

https://cloud.google.com/architecture/exporting-stackdriver-logging-elasticsearch

https://www.elastic.co/guide/en/cloud/current/ec-create-deployment.html


----------------------------------------------------


### 2.

* ### Make startup script with installed and configured tomcat on CentOS image.

- startup script in startup-tomcat-centos.sh file

* ### Make instance template for tomcat on CentOS.

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create instance-template-tomcat-centos-1 \
--machine-type=e2-medium \
--subnet=projects/tomcat-nginx-lb/regions/us-west1/subnetworks/backend-subnet \
--network-tier=PREMIUM \
--metadata=startup-script-url=gs://tomcat-bucket-centos/startup-tomcat-centos.sh \
--region=us-west1 \
--tags=allow-ssh,allow-http \
--image=centos-8-v20210721 \
--image-project=centos-cloud \
--boot-disk-size=20GB \
--boot-disk-type=pd-balanced
```

* ### Update MIG VM's.

- Update already working MIG instance-group-tomcat-1 with max autoscale oversize instance=1 and max unavailable instance=1.

```
gcloud compute instance-groups managed rolling-action start-update instance-group-tomcat-1 \
--version=template=instance-template-tomcat-centos-1 \
--max-surge=1 \
--max-unavailable=1 \
--zone=us-west1-b
```
* ### Previous version

![](img/1.png)

* ### Update 1

![](img/2.png)

* ### Update 2

![](img/3.png)

* ### Done 

![](img/4.png)

------------------------------------------

### 3. 

* ### Make health-check for internal LB for tomcat backend service checking.

```
gcloud compute health-checks create http tomcat-lb-check \
--region=us-west1 \
--port 8080
```

------------------------------------------


## Task_3

### Goals

1. Create a python3 function that will run through Pub/Sub and print a message.
2. Set this function to automatically start every hour.
3. Function should connect to BigQuery dataset and display statistics of HTTP responses for the last hour.
4. Create one more function that will run every time when Nginx have a '404' error and display the error message.

### Solution

### 1. 

* #### Create a python3 function that will run through Pub/Sub and print a message.

* #### Create Pub/Sub topic.

```
gcloud pubsub topics create function-topic
```

* ### Create python function what print pub/sub message.

![](img/13.png)

![](img/14.png)

* ### Publish message in Pub/Sub.

![](img/15.png)

* ### Check function 'print' in logs.

![](img/16.png)

-------------------------------------------------------

### 2. Set this function to automatically start every hour.

* ### Configure Cloud scheduler that function run every hour.

```
gcloud scheduler jobs create pubsub function-start --schedule="0 */1 * * *"
  --topic=function-topic --message-body="Every hour function startup"
```

* ### Check function auto-start in logs (Change schedule to "every minutes" for clarity) 
  
![](img/21.png)

-------------------------------------------------------


### 3. Make Function that connect to BigQuery dataset and display statistics of HTTP responses for the last hour.

* ### Prepare VM with Nginx and fluentd. 

```
# Startup script in startup-nginx.sh file 
```

* ### Configure Bigquery and log export.

![](img/17.png)

* ### Configure Service Account for Cloud Function.

```
gcloud iam service-accounts create connect-to-bigquery
gcloud projects add-iam-policy-binding <project-name> --member="serviceAccount:connect-to-bigquery@<project-name>.iam.gserviceaccount.com" --role="roles/owner"
```

* ### Create function that connect to BigQuery and print Nginx last hour access logs.

![](img/18.png)

* #### Python function code:

```
from google.cloud import bigquery

def hello_world(request):

  client = bigquery.Client()

  query = (
    'SELECT time, remote, host, code, path  FROM `fluentd.nginx_access` '
    'WHERE time > CURRENT_TIMESTAMP() - interval 1 hour '
    'ORDER BY time DESC '
    'LIMIT 100')

  query_job = client.query(query)

  print("The query data: ")
  for row in query_job:
    print("time {}, remote {}, host {}, code {}, path {}".format(row[0],row[1], row[2], row[3], row[4]))

  return f'The query run successfully'
```

![](img/20.png)

* ### Check Nginx logs.

![](img/19.png)

-------------------------------------

### 4. 

#### Create one more function that will run every time when Nginx have a '404' error and display the error message.

#### Option 1. Semi-automatic 404-logs function. 

* #### Create function what filter last 10 Nginx logs by code 404 and print it.

```
from google.cloud import bigquery

def hello_404():

  client = bigquery.Client()

  query = (
    'SELECT * FROM `fluentd.nginx_access` '
    'WHERE code = "404" ' 
    'ORDER BY time DESC '
    'LIMIT 10')

  query_job = client.query(query)

  print("The query data: ")
  for row in query_job:
    print("time {}, remote {}, method {}, code {}, path {}".format(row[0], row[1], row[4], row[6], row[5]))

  return f'The query run successfully'

hello_404()
```

* ### Make 'every minute' cron job through cloud scheduler.

```
gcloud scheduler jobs create pubsub error404-start --schedule="* * * * *" \
--topic=error-404 --message-body="Every minutes 404 check"
```

* ### Check logs.

![](img/22.png)

### Option 2. Full-automatic 404-logs function. 


* #### Install Nginx, install Ruby through RVM.
* #### Install gems: fluentd, fluentd-plugins.
* #### Configure fluent.conf
* #### Configure Nginx that '404' logs redirect to file 404.log
* #### Make 'all access' logs flow to Bigquery. (plugin fluent-plugin-bigquery)
* #### Make '404' logs flow to Pub/Sub that started Function what get last '404' log from 'all access' logs in Bigquery. (plugin fluent-plugin-gcloud-pubsub-custom)
 
* ### Install nginx and Ruby hrough RVM.

```
# Nginx
sudo apt install nginx -y

# gpg2
sudo apt install gnupg2 -y

# Ruby RVM
gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
rvm install 2.7
ruby -v
```

* ### Install gems: 

```
gem install fluentd --no-doc
fluentd --setup ./fluent
gem install fluent-plugin-bigquery --no-doc
gem install fluent-plugin-gcloud-pubsub-custom --no-doc
```

* ### Configure /etc/nginx/sites-available/default
* (Copy '404' logs to 404.log)  

```
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  root /var/www/html;
        
  index index.html index.htm index.nginx-debian.html;

  server_name _;

  location / {
    try_files $uri $uri/ =404;
  }

  error_page 404 /404.html;

  location = /404.html {
    access_log /var/log/nginx/404.log;
    internal;
  }
}
```

* ### Configure fluent.conf

```
# Replace the existing fluentd config file with new fluent.conf in repo. 
# (Configuration code added to the end of file)

# Start Fluentd as a daemon
fluentd -c ./fluent/fluent.conf &
```

* ### Check Pub/Sub test message.

![](img/23.png)

![](img/24.png)

* ### Create Cloud Function what triggered from Pub/Sub 'code-404' topic and pull last '404' log from Bigquery.

```
from google.cloud import bigquery

def hello_404():

  client = bigquery.Client()

  query = (
    'SELECT * FROM `fluentd.nginx_access` '
    'WHERE code = "404" ' 
    'ORDER BY time DESC '
    'LIMIT 1')

  query_job = client.query(query)

  print("The query data: ")
  for row in query_job:
    print("time {}, remote {}, method {}, code {}, path {}".format(row[0], row[1], row[4], row[6], row[5]))

  return f'The query run successfully'

hello_404()
```

* ### Check nginx path.

![](img/25.png)

* ### Check BigQuery logs.

![](img/26.png)

* ### Check Function logs.

![](img/27.png)

### [TOP](https://github.com/OLG-MAN/tomcat-nginx-lb#Task_1)

-------------------------------------------