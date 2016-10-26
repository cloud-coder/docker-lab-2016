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
