#Create stack by targeting the swarm manager
eval $(docker-machine env manager-1)
#Create needed networks
docker network create \
  --driver overlay \
  frontend

docker network create \
  --driver overlay \
  backend

docker network create \
  --driver overlay \
  logging
docker network ls

#Create named volumes
docker volume create --driver rexray --opt size=7 --name dbdata
docker volume create --driver rexray --opt size=7 --name esdata
docker volume ls


#Create db service and connect it to the backend network
docker service create \
  --name db \
  --network backend \
  --network logging \
  --replicas 1 \
  -e MONGODB_USER=dba \
  -e MONGODB_DATABASE=mycars \
  -e MONGODB_PASS=dbpass \
  --mount type=volume,source=dbdata,target=/data/db,volume-driver=rexray \
  cascon/db:latest

#Create the api service and connect it to the backend and frontend network
docker service create \
    --name api \
    --network backend \
    --network frontend \
    --network logging \
    --replicas 1 \
    --log-driver=gelf --log-opt gelf-address=udp://$(docker-machine ip manager-1):12201 \
    -e NODE_ENV=production \
    cascon/strongloop:latest

#Create the nginx gateway to strongloop and expose ingress 8080
docker service create \
    --name gateway \
    --network frontend \
    --network logging \
    --replicas 1 \
    -p 8080:80 \
    cascon/gateway:latest
