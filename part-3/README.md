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
