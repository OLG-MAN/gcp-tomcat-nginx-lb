# Tomcat(backend) and Nginx(frontend) in MIGs with LB.

## Task goals

1. Create bucket for Tomcat application files and another one for static web files (think about permissions)
2. Create MIG for backend with installed tomcat and on boot download demo application from bucket. Setup autoscaling by CPU (think about scale down)
3. Create bucket for Nginx application files and another one for static web files (think about permissions)
4. Add one more MIG for frontend with nginx, by path /demo/ show demo app from bucket, by path /img/picture.jpg show file from bucket
5. Create LB for tomcat and nginx
6. Setup export of nginx logs to bucket/BigQuery
7. Make SSL terination

## Solution
1. 
* Making bucket for tomcat through gcloud.

```

```

2. 
* Create instance template for tomcat MIG with startup script from bucket. (used startup.sh file in repo)

```
gcloud beta compute --project=tomcat-nginx-lb instance-templates create tomcat-template1 --machine-type=e2-medium --network=projects/tomcat-nginx-lb/global/networks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://tomcat-bucket1/start.sh --maintenance-policy=MIGRATE --service-account=1010500951238-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --tags=http-server,https-server --image=debian-10-buster-v20210721 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=tomcat-template1 --no-shielded-secure-boot --no-shielded-vtpm --no-shielded-integrity-monitoring --reservation-affinity=any
```

* Create Managed Instance Group from tomcat-template

```

```

4. 
* Create instance template for nginx MIG with startup script from bucket. (used startup-nginx.sh file in repo)

```

```