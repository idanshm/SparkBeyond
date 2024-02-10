#!/bin/bash
sudo -v

logs_dir="./logs"

if [ ! -d $logs_dir ]
then
    mkdir $logs_dir
fi

articles_mount_path="./articles"
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

installations_pre_check () {
    for tool in "docker" "kubectl" "helm" "minikube" "ifconfig" "sed" 
    do
        echo -n "Checking if $tool is installed..."
        if ! command -v $tool &> /dev/null
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
    docker build . -t ${docker_registry}:${docker_registry_port}/${docker_image}:${docker_tag} > $output_file 2>&1
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
    minikube start --insecure-registry="${docker_registry}:${docker_registry_port}" --mount --mount-string ${articles_mount_path}:/app/articles > $output_file 2>&1
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
    sudo sed -i "/^127\.0\.0\.1[[:space:]]\+localhost $docker_registry$/a $(minikube ip)       common-words.local" /etc/hosts
}

installations_pre_check
install_docker_local_registry
build_docker_image
push_docker_image
start_minikube
