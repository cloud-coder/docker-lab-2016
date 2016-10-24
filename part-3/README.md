# Introduction
In order to scale your application workloads for production needs, you need to select an orchestration framework.  There are a number of popular container orchestration frameworks available today (e.g. [Kubernetes](http://kubernetes.io/), [DCOS/Mesos](https://dcos.io/) and [Docker Swarm](https://docs.docker.com/engine/swarm/)).  This tutorial will help you setup Docker Swarm.


# Prerequisites
1. Install [Docker Toolbox](https://www.docker.com/products/docker-toolbox).  We leverage Docker Machine in the scripts to provision Docker 1.12+ on Virtual Box Linux VMs.  You could just install Docker Engine directly if you are on [Linux](https://docs.docker.com/engine/installation/).
1. Have a [Docker Hub](https://hub.docker.com/) account

# Step 1 - Setup Docker Swarm
1. Use docker-machine to provision Docker engine on three nodes (i.e. vms).
    
    ```
    docker-machine create -d virtualbox manager-1
    docker-machine create -d virtualbox worker-1
    docker-machine create -d virtualbox worker-2
    ```
1. Now take a look at the list of machines that are catalogued
    
    ```
    docker-machine ls --filter=driver=virtualbox
    ```
1. (Optional) Target the manager node, and start a simple [swarm visualizer](https://github.com/ManoMarks/docker-swarm-visualizer).

    ```
    eval $(docker-machine env manager-1)
    docker run -d -p 5000:5000 --name=swarm-viz \
     -e HOST=localhost \
     -e PORT=5000 \
     -e HOST=$(docker-machine ip manager-1) \
     -v /var/run/docker.sock:/var/run/docker.sock \
     manomarks/visualizer
    ```
1. Target the manager node, and make it the swarm master. Take note of command to join nodes to the swarm.  You will use this in the next step.

    ```
    eval $(docker-machine env manager-1)
    docker swarm init --advertise-addr $(docker-machine ip manager-1)
    ```

1. Join the worker nodes to the swarm.  To do this, target each machine in order, and issue the docker swarm join command that was output by the last step.

    ```
    eval $(docker-machine env worker-1)
    eval $(docker-machine env worker-2)
    ```

1. Target a manager node again, and docker view all of the nodes in the swarm.

    ```
    eval $(docker-machine env manager-1)
    docker node ls
    ```

1. A simple 3 node swarm is now setup.  The above steps were adapted from [Getting started with swarm mode](https://docs.docker.com/engine/swarm/swarm-tutorial/).  You can view details of your swarm with docker info on a manager node.

    ```
    eval $(docker-machine env manager-1)
    docker info
    ```
    
# (Optional) Step 2 - Setup shared storage between VMs
The Swarm will distrubute containers amongst VMs wherever there are resources available.  You can constrain where certain containers are run, but to have a truly scalable system, you should try to avoid that.  This means that containers that save state, need to mount volumes from a shared storage.  You could use NFS or some other block storage for this.  Docker provides a `volume driver` plugin framework.  Many third party storage providers are creating drivers.  In this tutorial, we will use EMC's [REX-Ray](http://rexray.readthedocs.io/en/stable/), since it works well with virtualbox.

1. Make sure that Virtualbox authentication is disabled to make the demo easier to complet and start the HTTP SOAP API.

    ```
    VBoxManage setproperty websrvauthlibrary null && vboxwebsrv --background
    export REXRAY_SERVER=$(docker-machine ip manager-1)
    export HOST_VOLUME_PATH=${PWD}/volumes
    ```
    
1. Install the REX-ray server on `manager-1`.  The versions are VERY IMPORTANT.  Unfortunately the project is still not 1.0 release, so the metadata format of the config file changes a lot amongst releases.

    ```
    docker-machine ssh manager-1 "curl -sSL https://dl.bintray.com/emccode/rexray/install | sh -s -- stable 0.5.1"
    docker-machine ssh manager-1 \
    "wget http://tinycorelinux.net/6.x/x86_64/tcz/udev-extra.tcz \
    && tce-load -i udev-extra.tcz && sudo udevadm trigger"
    docker-machine ssh manager-1 "sudo rexray service stop"
    docker-machine ssh manager-1 "sudo rm /etc/rexray/config.yml"
    
    docker-machine ssh manager-1 \
    "sudo tee -a /etc/rexray/config.yml << EOF
    rexray:
      logLevel: warn
    libstorage:
      host:     tcp://${REXRAY_SERVER}:7979
      embedded: true
      service:  virtualbox
      server:
        endpoints:
          public:
            address: tcp://${REXRAY_SERVER}:7979
        services:
          virtualbox:
            driver: virtualbox
    virtualbox:
      volumePath: ${HOST_VOLUME_PATH}
    "
    
    docker-machine ssh manager-1 "sudo rexray service start"
    docker-machine ssh manager-1 "docker volume ls"
    ```
    
1. Install the REX-ray client on worker-1

    ```
    docker-machine ssh worker-1 \
    "curl -sSL https://dl.bintray.com/emccode/rexray/install | sh -s -- stable 0.5.1"
    docker-machine ssh worker-1 \
    "wget http://tinycorelinux.net/6.x/x86_64/tcz/udev-extra.tcz \
    && tce-load -i udev-extra.tcz && sudo udevadm trigger"
    docker-machine ssh worker-1 "sudo rexray service stop"
    docker-machine ssh worker-1 "sudo rm /etc/rexray/config.yml"
    
    docker-machine ssh worker-1 \
    "sudo tee -a /etc/rexray/config.yml << EOF
    rexray:
      logLevel: warn
    libstorage:
      host:    tcp://${REXRAY_SERVER}:7979
      service: virtualbox
    "
    
    docker-machine ssh worker-1 "sudo rexray service start"
    docker-machine ssh worker-1 "docker volume ls"
    ```
    
1. Install the REX-ray client on worker-2

    ```
    docker-machine ssh worker-2 \
    "curl -sSL https://dl.bintray.com/emccode/rexray/install | sh -s -- stable 0.5.1"
    docker-machine ssh worker-2 \
    "wget http://tinycorelinux.net/6.x/x86_64/tcz/udev-extra.tcz \
    && tce-load -i udev-extra.tcz && sudo udevadm trigger"
    docker-machine ssh worker-2 "sudo rexray service stop"
    docker-machine ssh worker-2 "sudo rm /etc/rexray/config.yml"
    
    docker-machine ssh worker-2 \
    "sudo tee -a /etc/rexray/config.yml << EOF
    rexray:
      logLevel: warn
    libstorage:
      host:    tcp://${REXRAY_SERVER}:7979
      service: virtualbox
    "
    
    docker-machine ssh worker-2 "sudo rexray service start"
    docker-machine ssh worker-2 "docker volume ls"
    ```

## Step. 2.1 - Test the volume setup
Now test that shared storage works by creating a volume on worker-1 and validating that it is visible on worker-2.

1. Create a sample volume called `hellopersistence` and run a simple `busybox` container mounting that volume. Let's do this first with a standalone container.

    ```
    eval $(docker-machine env worker-1)
    docker volume rm hellopersistence
    docker volume create --driver rexray --opt size=1 --name hellopersistence
    docker run -tid --volume-driver=rexray -v hellopersistence:/mystore --name temp01 busybox
    docker exec temp01 touch /mystore/myfile
    ```

1. You should see myfile listed in the container volume.  Then we can remove the container (the volume will persist).

    ```
    docker exec temp01 ls /mystore
    docker rm -f temp01
    ```
    
1. Now target worker-2, and startup a new container there.  We mount the same named volume into the new container, and you should see the same `myfile` listed.

    ```
    docker run -tid --volume-driver=rexray -v hellopersistence:/mystore --name temp01 busybox
    docker exec temp01 ls /mystore
    docker rm -f temp01
    ```
    
1.  Now we will test with a Docker 1.12+ service, instead of a standalone container.  Remember to target a manager node when deploying services.

    ```
    eval $(docker-machine env manager-1)
    docker service create --replicas 1 --name nginx -p 8080:80 --mount \      type=volume,source=hellopersistence,target=/usr/share/nginx/html,volume-driver=rexray \
    nginx
    docker service ls
    docker service inspect --pretty nginx
    docker service ps nginx
    docker service rm nginx
    ```
    
1. Finally remove the volume

    ```
    docker volume rm hellopersistence
    ```

# Step 3 - Build Docker Images
We will build and push images to Docker Hub.  Don't forget to log into Docker Hub, and also to change the image names.  That is, you will not have permission to push images to `cascon/*` organization.

1. Log into Docker Hub

    ```
    eval $(docker-machine env manager-1)
    docker login
    ```
1. Build and push the database (mongodb), static web server (nginx) and REST backend (strongloop) from part 2.

    ```
    docker build --rm -t cascon/db ../part-2/db
    docker push cascon/db
    docker build --rm -t cascon/gateway ../part-2/gateway
    docker push cascon/gateway
    docker build --rm -t cascon/strongloop ../part-2/strongloop
    docker push cascon/strongloop
    ```
    
1. Later in the turorial we will deploy centralized logging using the [ELK stack](https://www.elastic.co/videos/introduction-to-the-elk-stack).  Let's build and push those images as well.

    ```
    docker build --rm -t cascon/elk-elasticsearch ./elk/elasticsearch
    docker push cascon/elk-elasticsearch
    docker build --rm -t cascon/elk-logstash ./elk/logstash
    docker push cascon/elk-logstash
    docker build --rm -t cascon/elk-kibana ./elk/kibana
    docker push cascon/elk-kibana
    ```
# Step 4 - Run the app
In this step, we will run the application you build in part 2.  This time though, we will run each container we defined in the Docker compose file, as a Docker 1.12+ service.  Services in Docker allow us to easily define scalable micro services that are highly available.  To learn more, I would recommend this [tutorial](https://docs.docker.com/engine/swarm/swarm-tutorial/) and this [video](https://www.youtube.com/watch?v=KC4Ad1DS8xU&). 





