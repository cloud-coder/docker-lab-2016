# Use docker-machine to provision Docker engine on three nodes (i.e. vms).  For non virtualbox --engine-install-url https://experimental.docker.com/
docker-machine create -d virtualbox manager-1
docker-machine create -d virtualbox worker-1
docker-machine create -d virtualbox worker-2
# Now take a look at the list of machines that are catalogued
docker-machine ls --filter=driver=virtualbox

#Target the manager node to make it the swarm master
eval $(docker-machine env manager-1)
#Start a simple swarm visualizer
docker run -d -p 5000:5000 --name=swarm-viz -e HOST=localhost -e PORT=5000 -e HOST=$(docker-machine ip manager-1) -v /var/run/docker.sock:/var/run/docker.sock manomarks/visualizer

docker swarm init --advertise-addr $(docker-machine ip manager-1)
#Take note of command to join nodes to the swarm
docker swarm join-token worker
docker swarm join-token manager

#Run docker info to view current state of the swarm
docker info

#Run the docker node ls command to view information about nodes
docker node ls

#Target worker-1 and worker-2 nodes to join them to manager-1
eval $(docker-machine env worker-1)
docker swarm join \
    --token SWMTKN-1-3a67j3avvu0j39trek68xbqzkbcfqpovxcs2n6hvbrifbwbaxa-4h3tcktsf67vgbky39gy45mlk \
    192.168.99.102:2377

eval $(docker-machine env worker-2)
docker swarm join \
    --token SWMTKN-1-3a67j3avvu0j39trek68xbqzkbcfqpovxcs2n6hvbrifbwbaxa-4h3tcktsf67vgbky39gy45mlk \
    192.168.99.102:2377

#Target a manager node again, and docker node ls to see all nodes in the swarm Now
eval $(docker-machine env manager-1)
docker node ls

# We want to have shared volumes across our Swram nodes.  To do this, you can use
# any third party docker volume provider.  We use http://rexray.readthedocs.io/en/stable/
# Virtualbox installation: http://rexray.readthedocs.io/en/stable/#installing-rex-ray

#Very important: The HTTP SOAP API can have authentication disabled by running
VBoxManage setproperty websrvauthlibrary null && vboxwebsrv --background
export REXRAY_SERVER=$(docker-machine ip manager-1)
export HOST_VOLUME_PATH=${PWD}/volumes

docker-machine ssh manager-1 "tce-load -wi nano"
#docker-machine ssh manager-1 "export TERM=xterm"
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
#docker-machine ssh manager-1 "rexray volume"
docker-machine ssh manager-1 "docker volume ls"


docker-machine ssh worker-1 "tce-load -wi nano"
#docker-machine ssh worker-1 "export TERM=xterm"
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

docker-machine ssh worker-2 "tce-load -wi nano"
#docker-machine ssh worker-2 "export TERM=xterm"
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

#Now test that volumes work with standalone container
eval $(docker-machine env worker-1)
docker volume rm hellopersistence
docker volume create --driver rexray --opt size=1 --name hellopersistence
docker run -tid --volume-driver=rexray -v hellopersistence:/mystore --name temp01 busybox
docker exec temp01 touch /mystore/myfile
#You should see myfile listed
docker exec temp01 ls /mystore
docker rm -f temp01

eval $(docker-machine env worker-2)
docker run -tid --volume-driver=rexray -v hellopersistence:/mystore --name temp01 busybox
#You should see myfile listed
docker exec temp01 ls /mystore
docker rm -f temp01

#Test that volumes work with new Docker 1.12 services
eval $(docker-machine env manager-1)
docker service create --replicas 1 --name nginx -p 8080:80 --mount \
  type=volume,source=hellopersistence,target=/usr/share/nginx/html,volume-driver=rexray \
  nginx
docker service ls
docker service inspect --pretty nginx
docker service ps nginx
docker service rm nginx
docker volume rm hellopersistence
