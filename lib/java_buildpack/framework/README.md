# JMX trans agent integration

## Download  and compile java application
As an example app spring-music or spring-petclinic app typically used.

spring-music: https://github.com/scottfrederick/spring-music

spring-petclinic: https://github.com/spring-projects/spring-petclinic

Spring-petclinic is described in this doc.
```bash
git clone https://github.com/spring-projects/spring-petclinic
```
Application should be compiled before deployment
```bash
cd spring-petclinic/
```
compile application
```bash
./mvnw package
```

## Create manifest. Example manifest looks like below.

 Here is example manifest
```bash
 applications:
 - name: spring-petclinic
   memory: 1G
   random-route: true
   path: target/spring-petclinic-1.5.1.jar
   buildpack: https://github.com/Altoros/java-buildpack#jmx-agent-integration
```
```bash
cd spring-petclinic
vim manifest.yml
```
and past your manifest in this file

Important things here:

a) buildback git path. Altoros modified buildpack used to attach and configure
jmx trans agent. Today's way is just using online version of buildpack

## Push application. The simpliest step. Just
cd to directory with application and manifest
```bash
cd spring-petclinic
```
and push application
```bash
cf push
```

## Create userprovided service
To let buildpack know that jmx agent is necessary UPS should be created. StatD
server location is shown in this UPS.

##### IMPORTANT: Service should have jmxtrans in it's name.
```bash
cf cups jmxtrans -p "credentials": { "host": "192.168.1.180", "port": "8125"}
```

## Bind userprovided service to application and restage app
```bash
cf bind-service spring-petclinic jmxtrans
cf restage spring-petclinic
```

After this statsD should recieve jmx metrics and push them to carbon
