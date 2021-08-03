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

1. 
* Making bucket for tomcat through gsutil.

```
gsutil mb gs://tomcat-bucket1
gsutil cp startup-tomcat.sh gs://tomcat-bucket1
```

2. 
* Create instance template for tomcat MIG with startup script from bucket. (used startup-tomcat.sh file in repo)

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create tomcat-template1 --machine-type=e2-medium --network=projects/tomcat-nginx-lb/global/networks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://tomcat-bucket1/startup-tomcat.sh --maintenance-policy=MIGRATE --service-account=1010500951238-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --tags=http-server,https-server --image=debian-10-buster-v20210721 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=tomcat-template1 --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any
```

* Create Managed Instance Group from tomcat-template 

```
gcloud compute --project=tomcat-nginx-lb instance-groups managed create instance-group-tomcat --base-instance-name=instance-group-tomcat --template=tomcat-template1 --size=1 --zone=us-central1-a

gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-tomcat" --zone "us-central1-a" --cool-down-period "60" --max-num-replicas "4" --min-num-replicas "2" --target-cpu-utilization "0.75" --mode "on"
```

3. 
* Making bucket for nginx through gsutil.

```
gsutil mb gs://nginx-bucket1
gsutil cp startup-nginx.sh gs://tomcat-bucket1
```

4. 
* Create instance template for nginx MIG with startup script from bucket. (used startup-nginx.sh file in repo)

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create nginx-template1 --machine-type=e2-medium --network=projects/tomcat-nginx-lb/global/networks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://nginx-bucket1/startup-nginx.sh --maintenance-policy=MIGRATE --service-account=1010500951238-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --tags=http-server,https-server --image=debian-10-buster-v20210721 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=tomcat-template1 --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any
```

* Create Managed Instance Group from nginx-template in Cloud Shell

```
gcloud compute --project=tomcat-nginx-lb instance-groups managed create instance-group-nginx --base-instance-name=instance-group-nginx --template=nginx-template1 --size=1 --zone=us-west2-a

gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-nginx" --zone "us-west2-a" --cool-down-period "60" --max-num-replicas "4" --min-num-replicas "2" --target-cpu-utilization "0.7" --mode "on"
```


---------------


* INT-LB tomcat

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create tomcat-template-int --machine-type=e2-medium --region=us-west1 --network=lb-network --subnet=backend-subnet --tags=allow-ssh,load-balanced-backend --metadata=startup-script-url=gs://tomcat-bucket1/startup-tomcat.sh --maintenance-policy=MIGRATE --service-account=1010500951238-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform  --image=debian-10-buster-v20210721 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=tomcat-temmplate-int --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any

gcloud compute --project=tomcat-nginx-lb instance-groups managed create instance-group-tomcat-int --base-instance-name=instance-group-tomcat-int --template=tomcat-template-int --size=1 --zone=us-west1-a

gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-tomcat-int" --zone "us-west1-a" --cool-down-period "60" --max-num-replicas "4" --min-num-replicas "2" --target-cpu-utilization "0.75" --mode "on"


gcloud compute backend-services add-backend l7-ilb-backend-service \
  --balancing-mode=UTILIZATION \
  --instance-group=instance-group-tomcat-int \
  --instance-group-zone=us-west1-a \
  --region=us-west1 
```

* TOMCAT INSTANCE 

```
gcloud beta compute --project=tomcat-nginx-lb instances create tomcat101 \
--zone=us-west1-a --machine-type=e2-medium --subnet=backend-subnet --network-tier=PREMIUM \
--metadata=startup-script-url=gs://tomcat-bucket1/startup-tomcat.sh \
--tags=allow-ssh,allow-http \
--image=debian-10-buster-v20210721 \
--image-project=debian-cloud \
--boot-disk-size=10GB \
```



* NEW TOMCAT MIG and LB

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create instance-template-tomcat-1 --machine-type=e2-medium --subnet=projects/tomcat-nginx-lb/regions/us-west1/subnetworks/backend-subnet --network-tier=PREMIUM --metadata=startup-script-url=gs://tomcat-bucket1/startup-tomcat.sh --maintenance-policy=MIGRATE --service-account=1010500951238-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --region=us-west1 --tags=allow-ssh,allow-http --image=debian-10-buster-v20210721 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=instance-template-tomcat-1 --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any

gcloud compute --project "tomcat-nginx-lb" health-checks create http "tomcat-healt-check" --timeout "5" --check-interval "10" --unhealthy-threshold "3" --healthy-threshold "2" --port "8080" --request-path "/"

gcloud beta compute --project=tomcat-nginx-lb instance-groups managed create instance-group-tomcat-1 --base-instance-name=instance-group-tomcat-1 --template=instance-template-tomcat-1 --size=1 --zone=us-west1-b --health-check=tomcat-healt-check --initial-delay=300

gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-tomcat-1" --zone "us-west1-b" --cool-down-period "60" --max-num-replicas "4" --min-num-replicas "2" --target-cpu-utilization "0.6" --mode "on"
```

* NGINX INSTANCE

```
gcloud beta compute --project=tomcat-nginx-lb instances create nginx102 \
--zone=us-west1-a --machine-type=e2-medium --subnet=backend-subnet --network-tier=PREMIUM \
--metadata=startup-script-url=gs://nginx-bucket1/startup-nginx.sh \
--tags=allow-ssh,allow-http \
--image=debian-10-buster-v20210721 \
--image-project=debian-cloud \
--boot-disk-size=10GB \
```

* NGINX MIG and LB

- MIG
```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create instance-template-nginx-1 --machine-type=e2-medium --subnet=projects/tomcat-nginx-lb/regions/us-west1/subnetworks/backend-subnet --network-tier=PREMIUM --metadata=startup-script-url=gs://nginx-bucket1/startup-nginx.sh --maintenance-policy=MIGRATE --service-account=1010500951238-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --region=us-west1 --tags=allow-ssh,allow-http --image=debian-10-buster-v20210721 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=instance-template-nginx-1 --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any

gcloud compute --project "tomcat-nginx-lb" health-checks create http "nginx-health-check" --timeout "5" --check-interval "10" --unhealthy-threshold "3" --healthy-threshold "2" --port "80" --request-path "/"

gcloud beta compute --project=tomcat-nginx-lb instance-groups managed create instance-group-nginx-1 --base-instance-name=instance-group-nginx-1 --template=instance-template-nginx-1 --size=1 --zone=us-west1-b --health-check=nginx-health-check --initial-delay=300

gcloud beta compute --project "tomcat-nginx-lb" instance-groups managed set-autoscaling "instance-group-nginx-1" --zone "us-west1-b" --cool-down-period "70" --max-num-replicas "4" --min-num-replicas "2" --target-cpu-utilization "0.6" --mode "on"

```
- LB
```

```