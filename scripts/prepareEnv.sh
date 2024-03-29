#!/bin/bash

logs_dir="./logs"
required_tools=("docker" "kubectl" "helm" "minikube" "ifconfig" "sed")

helm_charts_path="$(dirname "$PWD")/charts"
articles_mount_path="$(dirname "$PWD")/articles"
docker_registry="registry.dev.svc.cluster.local"
docker_registry_port=5000
docker_image="common-words"
docker_tag="latest"

add_timestamp() {
    local timestamp=$(date +"%Y-%m-%d %T")
    while IFS= read -r line; do
        echo -e "'\e[90m'[$timestamp] \e[34m[$1]: \e[0m$line"
    done
}

create_logs_dir() {
    if [ ! -d $logs_dir ]
    then
        mkdir $logs_dir
    fi
}

installations_pre_check () {
    for tool in "${required_tools[@]}"
    do
        echo -n "Checking if $tool is installed..."
        if ! command -v "$tool" &> /dev/null
        then
            echo "Missing"
            exit 1
        else
            echo "OK"
        fi
    done
}

install_docker_local_registry () {
    local log_file="$logs_dir/docker_registry.log"
    local output_file="/tmp/docker_output.log"
    
    # Install docker local registry
    echo -n "Installing docker local registry..."
    docker run -d -p ${docker_registry_port}:${docker_registry_port} --restart=always --volume ~/.registry/storage:/var/lib/registry registry:2 > $output_file 2>&1
    local exit_code=$?
    
    add_timestamp "${FUNCNAME[0]}"< "$output_file" >> $log_file
    
    if [ $exit_code -eq 0 ] 
    then
        echo "OK"
    else
        echo "Failed"
        echo "See $log_file for more information"
        exit 1
    fi
    
    # Create docker directory for daemon.json
    if [ ! -d /etc/docker ]; then
        sudo mkdir /etc/docker || { echo "Failed to create /etc/docker directory"; exit 1; }
    fi

    # Set insecure registry for our local registry domain
    echo -n "Setting up Docker insecure registries..."
    if sudo sh -c 'echo "{\"insecure-registries\": [\"'${docker_registry}:${docker_registry_port}'\"]}" > /etc/docker/daemon.json'
    then
        echo "OK"
    else
        echo "Failed"
        exit 1
    fi

    # Restart docker daemon
    echo -n "Restarting docker daemon..."
    if sudo systemctl restart docker
    then   
        echo "OK"
    else
        echo "Failed"
        exit 1
    fi

    # Insert our docker registry DNS record to hosts file
    echo -n "Adding local registry DNS record to /etc/hosts..."
    if sudo sed -i '/^127\.0\.0\.1[[:space:]]/ s/$/ '${docker_registry}'/' /etc/hosts
    then
        echo "OK"
    else
        echo "Failed"
        exit 1
    fi
}

build_docker_image () {
    local log_file="$logs_dir/docker_build.log"
    local output_file="/tmp/docker_output.log"
    
    # Build our docker image
    echo -n "Building docker image..."
    docker build -f ../Dockerfile .. -t ${docker_registry}:${docker_registry_port}/${docker_image}:${docker_tag} > $output_file 2>&1
    local exit_code=$?

    add_timestamp "${FUNCNAME[0]}"< $output_file >> $log_file
    
    if [ $exit_code -eq 0 ]
    then
        echo "OK"
    else
        echo "Failed. See $log_file for more information"
        exit 1
    fi
}

push_docker_image () {
    local log_file="$logs_dir/docker_push.log"
    local output_file="/tmp/docker_output.log"

    # Push docker image to local registy
    echo -n "Pushing docker image to local registry..."
    docker push ${docker_registry}:${docker_registry_port}/${docker_image}:${docker_tag} > $output_file 2>&1
    local exit_code=$?
    
    add_timestamp "${FUNCNAME[0]}"< $output_file >> $log_file
    
    if [ $exit_code -eq 0 ]
    then
        echo "OK"
    else
        echo "Failed. See $log_file for more information"
        exit 1
    fi
}

start_minikube () {
    local log_file="$logs_dir/minikube.log"
    local output_file="/tmp/docker_output.log"

    echo -n "Starting minikube..."
    minikube start --insecure-registry="${docker_registry}:${docker_registry_port}" --mount --mount-string "${articles_mount_path}:/mnt/articles" > $output_file 2>&1
    local exit_code=$?

    add_timestamp "${FUNCNAME[0]}"< $output_file >> $log_file
    
    if [ $exit_code -eq 0 ]
    then
        echo "OK"
        sleep 3
    else
        echo "Failed. See $log_file for more information"
        exit 1
    fi

    echo -n "Installing minikube ingress addon..."
    minikube addons enable ingress > $output_file 2>&1
    local exit_code=$?
    
    add_timestamp "${FUNCNAME[0]}"< $output_file >> $log_file

    if [ $exit_code -eq 0 ]
    then
        echo "OK"
    else
        echo "Failed"
        exit 1
    fi

    # This IP address will allow processes in Minikube to reach the registry running on your host. 
    # Configuring a fixed IP address avoids the problem of the IP address changing whenever you connect your machine to a different network. 
    # If your machine already uses the 172.16.x.x range for other purposes, choose an address in a different range e.g. 172.31.x.x..
    export DEV_IP=172.16.1.1
    echo -n "Setting up fixed ip address $DEV_IP..."
    if sudo ifconfig lo:0 $DEV_IP
    then
        echo "OK"
    else
        echo "Failed"
        exit 1
    fi

    # Add an entry to /etc/hosts inside the minikube VM, pointing the registry to the IP address of the host. 
    # This will result in registry.dev.svc.cluster.local resolving to the host machine allowing the docker daemon in minikube to pull images from the local registry. 
    # This uses the DEV_IP environment variable from the previous step.
    echo -n "Adding docker local registry DNS record to minikube..."
    minikube ssh "echo \"$DEV_IP       $docker_registry\" | sudo tee -a /etc/hosts" > $output_file 2>&1
    local exit_code=$?
    
    add_timestamp "${FUNCNAME[0]}"< $output_file >> $log_file

    if [ $exit_code -eq 0 ]
    then
        echo "OK"
    else
        echo "Failed"
        exit 1
    fi

    # Add DNS record to our minikube
    sudo sed -i "/^127\.0\.0\.1[[:space:]]\+localhost $docker_registry$/a $(minikube ip)       common-words.local prometheus.local grafana.local loki.local" /etc/hosts
}

init() {
    sudo -v
    echo "Initializing environment..."
    create_logs_dir
    installations_pre_check
    install_docker_local_registry
    build_docker_image
    push_docker_image
    start_minikube
}

reset() {
    sudo -v
    echo "Resetting environment..."
    minikube delete
    docker rm -f $(docker ps -aq)
    docker rmi -f $(docker images -aq)
    sudo rm -rf /etc/docker
    sudo cp ./hosts /etc/hosts
    echo "env reset done!"

    exit 0
}

docker_rebuild() {
    echo "Starting docker image rebuild..."
    build_docker_image
    push_docker_image
}

deploy() {
    if ! kubectl get namespace monitoring > /dev/null 2>&1
    then
        echo "namespace monitoring not found"
        kubectl create namespace monitoring
    fi
    if ! kubectl get namespace logging > /dev/null 2>&1
    then
        echo "namespace logging not found"
        kubectl create namespace logging
    fi

    echo "Waiting for nginx-ingress-controller to become Ready..."
    kubectl get pod -n ingress-nginx | grep ingress-nginx-controller | awk '{print $1}' | xargs kubectl wait pod --for=condition=Ready --timeout=300s -n ingress-nginx
    echo "Deploying prometheus..."
    helm install prometheus "${helm_charts_path}/prometheus" -f "${helm_charts_path}/prometheus/values.yaml" -n monitoring --wait --timeout 5m
    echo "Deploying loki..."
    helm install loki "${helm_charts_path}/loki" -f "${helm_charts_path}/loki/values.yaml" -n logging --wait --timeout 5m
    echo "Deploying grafana..."
    helm install grafana "${helm_charts_path}/grafana" -f "${helm_charts_path}/grafana/values.yaml" -n monitoring --wait --timeout 5m
    echo "Deploying common-words..."
    helm install common-words "${helm_charts_path}/common-words" -f "${helm_charts_path}/common-words/values.yaml" -n default --wait --timeout 5m
}

case $1 in
  init)
    init
    ;;
  reset)
    reset
    ;;
  docker-rebuild)
    docker_rebuild
    ;;
  deploy)
    deploy
    ;;
  *)
    echo "Usage: $0 [init|reset|docker-rebuild]"
    exit 1
    ;;
esac

