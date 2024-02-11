# Common-words app instructions
This app uses FastAPI Python module.  
It will read all files under the articles folder,  will check if the files are valid txt files.  
It will then randomly select 4 articles, and return the 10 most common words in each article.  

The articles folder is mounted to minikube so you can dynamically add or remove articles from the folder.

## Important!!
This setup is tested on:  

Distributor ID:	Ubuntu  
Description:	Ubuntu 22.04.3 LTS  
Release:	22.04  
Codename:	jammy  

Please make sure you are testing on a clean Ubuntu installation and the same release.

## Deploy stetps:
required tools: docker, kubectl, helm, minikube, ifconfig, sed
```bash
$ cd ./scripts
```

```bash
$ prepareEnv.sh init
Initializing environment...
Checking if docker is installed...OK
Checking if kubectl is installed...OK
Checking if helm is installed...OK
Checking if minikube is installed...OK
Checking if ifconfig is installed...OK
Checking if sed is installed...OK
Installing docker local registry...OK
Setting up Docker insecure registries...OK
Restarting docker daemon...OK
Adding local registry DNS record to /etc/hosts...OK
Building docker image...OK
Pushing docker image to local registry...OK
Starting minikube...OK
Installing minikube ingress addon...OK
Setting up fixed ip address 172.16.1.1...OK
Adding docker local registry DNS record to minikube...OK
```  
```bash
$ prepareEnv.sh deploy
```
## Deploy script usage:


### Init environment:
Initialize the environment.  
The script will make sure the required tools are installed ( such as helm )  
install local docker registry, build the docker image etc...
```bash
$ prepareEnv.sh init
```

### Reset environment:
The script will reset the environment.  
Basically it will reverse the init step.  
Take into account that this will also reset the /etc/hosts file  
Use this with caution!
```bash
$ prepareEnv.sh reset
```

### Re-build docker image:
Rebuild the docker image and push the new version to the local registry.  
In case you made some code changes..
```bash
$ prepareEnv.sh docker-rebuild
```

### Deploy helm charts:
Create monitoring namespace and deploy the helm charts.
```bash
$ prepareEnv.sh deploy
```

## Grafana
Ingress is enabled, visit http://grafana.local  
Default user: admin  
Default password: admin  

## Prometheus
Ingress is enabled, visit http://prometheus.local  
Added scrape job for common-words app.  

