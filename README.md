## Tomcat(backend) and Nginx(frontend) in MIGs with LB.

## Task goals

1. Create bucket for Tomcat application files and another one for static web files (think about permissions).
2. Create MIG for backend with installed tomcat and on boot download demo application from bucket. Setup autoscaling by CPU (think about scale down).
3. Create bucket for Nginx application files and another one for static web files (think about permissions).
4. Add one more MIG for frontend with nginx, by path /demo/ show demo app from bucket, by path /img/picture.jpg show file from bucket.
5. Create LB for tomcat and nginx.
6. Setup export of nginx logs to bucket/BigQuery.
7. Make SSL terination.

## Solution using Cloud Shell

### Configuring Network

* #### Delete default VPC. Make new VPC with 2 subnets (for backend,frontend and for proxy)

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

* #### Configuring firewall rules

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


1. 
* #### Making buckets for tomcat and nginx through gsutil. 

```
gsutil mb gs://tomcat-bucket1
gsutil cp startup-tomcat.sh gs://tomcat-bucket1
gsutil cp sample.war gs://tomcat-bucket1

gsutil mb gs://nginx-bucket1
gsutil cp startup-nginx.sh gs://nginx-bucket1

gsutil mb gs://nginx-bucket12
gsutil cp 101.png gs://nginx-bucket12
```

* #### Make Public access for nginx-bucket12
```
gsutil iam ch allUsers:objectViewer gs://nginx-bucket12
```

2. 
* #### Create instance template for tomcat MIG with startup script from bucket. (used startup-tomcat.sh file in repo)

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create instance-template-tomcat-1 \
--machine-type=e2-medium \
--subnet=projects/tomcat-nginx-lb/regions/us-west1/subnetworks/backend-subnet \
--network-tier=PREMIUM \
--metadata=startup-script-url=gs://tomcat-bucket1/startup-tomcat.sh
--region=us-west1 \
--tags=allow-ssh,allow-http \
--image=debian-10-buster-v20210721 \
--image-project=debian-cloud \
--boot-disk-size=10GB \
--boot-disk-type=pd-balanced
```

* #### Create Managed Instance Group from tomcat 

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
--size=1 --zone=us-west1-b \
--health-check=tomcat-healt-check \
--initial-delay=300

gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-tomcat-1" \
--zone "us-west1-b" \
--cool-down-period "60" \
--max-num-replicas "4" \
--min-num-replicas "2" \
--target-cpu-utilization "0.8" \
--mode "on"
```

3. 
* #### Making Internal LB for tomcat MIG

* #### Health check for tomcat MIG

```
gcloud compute health-checks create http tomcat-mig-check \
--region=us-west1 \
--port "8080" 
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
--instance-group=instance-group-tomcat-1 \
--instance-group-zone=us-west1-b \
--region=us-west1
```

* #### URL map (will lb name)

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

4. 
* #### Create instance template for nginx MIG with startup script from bucket. (used startup-nginx.sh file in repo)

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create nginx-template-1 \
--machine-type=e2-medium \
--network=projects/tomcat-nginx-lb/global/networks/lb-network \
--network-tier=PREMIUM \
--metadata=startup-script-url=gs://nginx-bucket1/startup-nginx.sh \
--tags=allow-http,allow-ssh \
--image=debian-10-buster-v20210721 \
--image-project=debian-cloud \
--boot-disk-size=10GB \
--boot-disk-type=pd-balanced
```

* #### Create Managed Instance Group from Nginx

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
--zone=us-west1-a

gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-nginx-1" \
--zone "us-west1-a" \
--cool-down-period "60" \
--max-num-replicas "4" \
--min-num-replicas "2" \
--target-cpu-utilization "0.8" \
--mode "on"
```

5. 
* #### Extarnal LB for Nginx MIG

* #### Named port

```
gcloud compute instance-groups set-named-ports instance-group-nginx \
    --named-ports http:80 \
    --zone us-west1-a
```

* #### Firewall rule

```
gcloud compute firewall-rules create fw-allow-health-check \
    --network=default \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-health-check \
    --rules=tcp:80
```

* #### Reserving an external IP address

```
gcloud compute addresses create lb-ipv4-1 \
    --ip-version=IPV4 \
    --global
```
And describe IP
```
gcloud compute addresses describe lb-ipv4-1 \
    --format="get(address)" \
    --global
```

* #### Health check for tomcat MIG LB

```
gcloud compute health-checks create http nginx-mig-check \
--port 80
```

* #### Backend service

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
    --instance-group=instance-group-nginx \
    --instance-group-zone=us-west1-a \
    --global
```

* #### URL map (wil be LB name)

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

--------------------------------------------------

6. Analyzing logs, Fluentd and BigQuery

