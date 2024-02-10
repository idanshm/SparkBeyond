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

## Deploy script usage:
**script logs can be found under ./scripts/logs dir  
cd to ./scripts dir

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



