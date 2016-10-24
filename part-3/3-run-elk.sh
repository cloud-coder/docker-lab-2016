eval $(docker-machine env manager-1)

#elasticsearch
docker service create \
  --name elasticsearch \
  --replicas 1 \
  --network logging \
  -e LOGSPOUT=ignore \
  --mount type=volume,source=esdata,target=/usr/share/elasticsearch/data,volume-driver=rexray \
  cascon/elk-elasticsearch:latest

#logstash
docker service create \
  --name logstash \
  --replicas 1 \
  --network logging \
  -e LOGSPOUT=ignore \
  -p 12201:12201/udp \
  cascon/elk-logstash:latest logstash -f /opt/logstash/conf.d/logstash.conf

#kibana
docker service create \
  --name kibana \
  --replicas 1 \
  --network logging \
  -e LOGSPOUT=ignore \
  -p 5601:5601 \
  cascon/elk-kibana:latest
