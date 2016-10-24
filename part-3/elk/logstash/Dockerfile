FROM logstash:2.4
ADD ./logstash.conf /opt/logstash/conf.d/logstash.conf
RUN apt-get -y update  && apt-get install -y curl nano
EXPOSE 5000 5000/udp 12201 12201/udp
