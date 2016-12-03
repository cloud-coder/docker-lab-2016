#! /bin/sh

#Don't forget to login to your Docker registry (e.g. Dockerhub)
#Build app
docker build --rm -t cascon/db ./db
docker push cascon/db
docker build --rm -t cascon/gateway ./gateway
docker push cascon/gateway
docker build --rm -t cascon/strongloop ./strongloop
docker push cascon/strongloop

#Build elk stack
docker build --rm -t cascon/elk-elasticsearch ./elk/elasticsearch
docker push cascon/elk-elasticsearch
docker build --rm -t cascon/elk-logstash ./elk/logstash
docker push cascon/elk-logstash
docker build --rm -t cascon/elk-kibana ./elk/kibana
docker push cascon/elk-kibana

#Pull images on nodes to make container startup faster
eval "$(docker-machine env manager-1)"
docker pull cascon/db
docker pull cascon/gateway
docker pull cascon/strongloop
docker pull cascon/elk-elasticsearch
docker pull cascon/elk-logstash
docker pull cascon/elk-kibana
eval "$(docker-machine env worker-1)"
docker pull cascon/db
docker pull cascon/gateway
docker pull cascon/strongloop
docker pull cascon/elk-elasticsearch
docker pull cascon/elk-logstash
docker pull cascon/elk-kibana
eval "$(docker-machine env worker-2)"
docker pull cascon/db
docker pull cascon/gateway
docker pull cascon/strongloop
docker pull cascon/elk-elasticsearch
docker pull cascon/elk-logstash
docker pull cascon/elk-kibana
