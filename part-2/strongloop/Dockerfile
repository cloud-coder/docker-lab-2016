FROM sgdpro/nodeslc

ADD ./app/package.json /home/strongloop/app/package.json
WORKDIR /home/strongloop/app
RUN npm install

ADD ./app /home/strongloop/app
VOLUME /home/strongloop/app
# ENV NODE_ENV production
CMD [ "./start.sh" ]
