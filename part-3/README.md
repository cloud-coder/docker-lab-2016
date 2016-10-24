# Introduction
In order to scale your application workloads for production needs, you need to select an orchestration framework.  There are a number of popular container orchestration frameworks available today (e.g. [Kubernetes](http://kubernetes.io/), [DCOS/Mesos](https://dcos.io/) and [Docker Swarm](https://docs.docker.com/engine/swarm/)).  This tutorial will help you setup Docker Swarm.


# Prerequisites
1. Install [Docker Toolbox](https://www.docker.com/products/docker-toolbox).  We leverage Docker Machine in the scripts to provision Docker 1.12+ on Virtual Box Linux VMs.  You could just install Docker Engine directly if you are on [Linux](https://docs.docker.com/engine/installation/).

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
