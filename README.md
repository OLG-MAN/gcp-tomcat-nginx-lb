## Tomcat(backend) and Nginx(frontend) in MIGs with LB.

## Task goals

1 Create bucket for Tomcat application files and another one for static web files (think about permissions)
2 Create MIG for backend with installed tomcat and on boot download demo application from bucket. Setup autoscaling by CPU (think about scale down)
3 Create bucket for Nginx application files and another one for static web files (think about permissions)
4 Add one more MIG for frontend with nginx, by path /demo/ show demo app from bucket, by path /img/picture.jpg show file from bucket
5 Create LB for tomcat and nginx
6 Setup export of nginx logs to bucket/BigQuery
7 Make SSL terination

## Solution using Cloud Shell

1. 
* Making bucket for tomcat through gsutil.

```
gsutil mb gs://tomcat-bucket1
gsutil cp startup-tomcat.sh gs://tomcat-bucket1
```

2. 
* Create instance template for tomcat MIG with startup script from bucket. (used startup.sh file in repo)

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
