#Scale the api to take on more load
docker service scale api=4

#Drain the node that has the db.  This will force the db to be scheduled on another active node
docker node update --availability drain <node>
#After the node is drained we should see that the api needs a reboot.
#Since there is no docker service restart yet.  Here is a hack.
docker service update --env-add UPDATE=1 api
