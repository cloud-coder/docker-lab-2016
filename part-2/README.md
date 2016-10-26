# Workshop - Part 2
This lab offers an introduction to concepts and commands used in Docker Compose tool. We reinforce the concepts by taking a simple web application which is made up of three containers, and define a Compose file for it. And start, stop and scale the application using this compose file.

Upon completing this lab you learn:
* Docker Compose concepts and commands
* How to build a multi-container application
* How to start, scale and view container logs

## Docker Compose
Typically applications are made up of two or more separate runtimes. For instance a web application has a runtime where web artifacts are served, but it also would requires other capabilities such as database, caching, gateway, messaging, etc. In a Container based solution, each capability is hosted in its own container. Separating capabilities in their own containers in this manner allow a solution the flexibility to scale each of these components according to the application usage patterns and needs. This flexibility adds some level of complexity, because now a single application has dependencies on several components and these dependencies are not readily evident.

Docker Compose is a tool that allows defining a multi container application in a single file. Therefore to take advantage of Docker Compose all you really need is to create the Compose file and use your containers.

To start your application and all its components (services), you need the following:
1. A *Docker container* _per service_ (e.g. web, db...): you already know how to create a Docker container. It is important that the container you create is defined using a Dockerfile, rather than manually created and committed.
2. You also need a *Compose file* that defines all the services that make up your application. The default name that the tool looks for is called *docker-compose.yml*.
3. You can now start the application, with all its parts (services), using the `docker-compose up` command (from the same directory where the compose file is located)

Docker Compose is useful for a single host environment like development or test/build. A developer can run different versions of the same application in their local machine and without worrying about conflicting dependencies.


## Application
The sample application that we are using for this lab has three services:
* Database (MongoDB)
* Web runtime (Node)
* Gateway (Nginx)

If we were to set up a development environment for such an application, we would have done the following:
* Install all the three runtimes in our local machine
* Add the sample test data to the database
* Add the application code and configuration
* Configure the gateway 

However using container based approach, none of these steps are necessary. A developer can simply pull the relevant containers into their local machine and start all the three containers to get a functioning application. However, there would be some inconveniences with this approach, such as considerations for networking such as db server host name (accessed from the web server), or gateway configuration (referencing the web server). We can improve on this already convenient situation by using a Compose file. All we need to do is define the Compose file representing this application, and then build and run the application in a single command. This approach also addresses the networking and storage concerns. It provides a consistent configuration across all developer machines. This will later be extended into production settings, as you will see in next lab.

As mentioned earlier, we first create the necessary container images by creating the relevant Dockerfiles, then create Compose file and finally start the application. The creation of the images is what we already covered in the first lab. Additionally the creation of the API app is out of scope for this lab, therefore we will just clone a repository that already has all these steps taken.

1. Open a command prompt and execute the following commands
```bash
cd ~/workshop
git clone https://github.com/cloud-coder/docker-lab-2016.git
cd docker-lab-2016/part-2
```
2. Verify you see the three directories: _db, gateway and strongloop_
3. Verify that _docker_compose.yml_ is there too

Let's examine each of the containers

### Database Container
The database container is based on MongoDB. Open the `~/workshop/docker-lab-2016/part-2/db/Dockerfile` in an editor

```dockerfile
FROM tutum/mongodb
```
This is a Dockerfile that is based on a well-known image. We are using this image because it offers a convenient way to start using MongoDB immediately, with little upfront configuration. This image accepts environment variables that can be used to set the DB user name, password and database name. These values are:
```bash
MONGODB_USER=dba
MONGODB_DATABASE=mycars
MONGODB_PASS=dbpass
```
We look at how to set these enviornment variables in the Compose file later.

### API Container
We are using a StrongLoop Loopback application that offers a single endpoint (_/api/Cars_) to perform simple create/read/update/delete (CRUD) operations. The Dockerfile for the image is located at `~/workshop/docker-lab-2016/part-2/strongloop/Dockerfile`. The contents of the file are:
```dockerfile
FROM sgdpro/nodeslc

ADD ./app/package.json /home/strongloop/app/package.json
WORKDIR /home/strongloop/app
RUN npm install

ADD ./app /home/strongloop/app
VOLUME /home/strongloop/app
CMD [ "./start.sh" ]
```

And the application source code is in the `~/workshop/docker-lab-2016/part-2/strongloop/app` directory.

This is a simple API server application based on Loopback. In addition to adding a Car model, the only external configuration change made is in the `~/workshop/docker-lab1/part-2/strongloop/app/server/datasources.json` file, which contains datasource connectivity information, and in our case refers to the MongoDB database in its container. The _memdb_ definition is there by default, we only added the second definition for our own MongoDB server

```json
{
  "memdb": {
    "name": "memdb",
    "localStorage": "",
    "file": "memdb.json",
    "connector": "memory"
  },
  "mongo": {
    "name": "mongo",
    "host": "db",
    "port": 27017,
    "database": "mycars",
    "user": "dba",
    "password": "dbpass",
    "connector": "mongodb"
  }
}
```

> **Note:**
> We are refering to the database host name simply as _db_. This would work only if the application container could translate db to the actual IP of the db container, or somehow use a DNS make this translation (perhaps using _/etc/hosts_). This is where Docker Compose and its networking capabilities come in handy. The usage of _link_ in Docker Compose is deprecated, so we will not discuss this in this lab.

### Gateway Container
We expose the API offered by our application through an Nginx server. You are already familiar with Nginx from the first the lab. The Dockerfile for this container is located in the `~/workshop/docker-lab1/part-2/gateway/Dockerfile` directory. Its contents are:
```dockerfile
FROM nginx
COPY sample_app_nginx.conf /etc/nginx/nginx.conf
```

We include our application routing information in the _sample_app_nginx.conf_ file. The following snippet is what we added:

```nginx
location /api {
	proxy_pass   http://api:3000;
}
```

## Converting to Docker Compose
As mentioned earlier, it is inconvenient to work with three separate containers and start/stop them one at a time, or to work out the networking concerns. Therefore we will use a Compose file to define the composition of our application. In our application, we have three distinct services, these three services are: db, api and gateway. We will reference these services, with their configuration and dependencies in a single file and link them together.

A Compose file is defined using YAML format. It contains _services_, _networking_ and _volume_ information for the application.
>**Note**
> There are two versions of Compose files. We use the version 2 definition.

### Docker Compose File
For your convenience the Compose file is already created and available at `~/workshop/docker-lab1/part-2/docker-compose.yml`. Open this file in an editor and let's examine its contents.

> **Note** We are using 2 spaces for indentation

The file starts with a Compose file version definition
```yaml
version: "2"
```

The Compose file has two top level definitions: _services_ and _networks_

In the _services_ section we define the three _db_, _api_ and _gateway_ services. And in the _networks_ section we define the two networks: _frontend_ and _backend_, which we will use to place each service in.

When a service (i.e. container) is placed in a network, it can only communicate with other containers that are in the same network. This allows a level separation/security, where for example a gateway container cannot communicate with the database container.

Below is the _networks_ definition, and we are currently using a bridge configuration.
>**Note** There is another possibility for network definition called _overlay_, which we will see in the Docker Swarm configuration in the next demo. 
```yaml
networks:
  frontend:
    #driver: overlay
  backend:
    #driver: overlay
```
Below is the _gateway_ service definition which is a child of `services` definition:
```yaml
  gateway:
    build: ./gateway
    ports:
      - "8080:80"
    networks:
      - frontend
```
Let's examine each configuration item:
* **build:** This definition references a container to be built from a _Dockerfile_ located in the _gateway_ directory, which we examined earlier.
* **ports:** Defines a port mapping where port _80_ in the container maps to port _8080_ on the host where the container is running.
* **networks:** Defines the networks this service will be placed in (connected to)

Here is the _api_ service definition, which like _gateway_ is a child of the `services` definition:
```yaml
  api:
    build: ./strongloop
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
    networks:
      - frontend
      - backend
    volumes:
      - ${PWD}/strongloop/app:/home/strongloop/app
    depends_on:
      - "db"
```
The new configuration items are:
* **enviornment:** Defines environment variables that will be set in the container when it starts
* **volumes:** Defines the volumes that will be mounted in the container
* **depends_on:** Defines that this service (i.e. *api*) depends on the the *db* service, and should start only when *db* is started.

> **Note:** This is a soft dependency, and it only means that the container is started. However the actual process and the bootstraping steps to make the service truly available is not considered. There are other custom approaches that can be used to make this dependency more specific.

The _db_ service does not have any new definitions, it just defined multiple port and environment variable definitions.

## Docker Compose commands
Now we have an application that is ready to be started and tested as a Docker Compose application.

### Start the Application
Let's first start the compose the application
1. Open a command prompt
2. Navigate to the `~/workshop/docker-lab1/part-2` directory
```bash
cd ~/workshop/docker-lab1/part-2
```
3. Start the Compose application
```bash
docker-compose up -d
```
This command will trigger a build, and then start each service, considering the dependencies.

### Examine Application Status
Now that we have started all these three services in the background, using the **-d** switch, how do we determine if all the services started? Similar to the `docker ps` command that you learned in the first lab, you can use `docker-compose ps` command to verify the status of each container.

1. In the same command prompt where you started the Compose application, run the following command
```
docker-compose up -d
```

You will see results like below:
```
Creating network "part2_frontend" with the default driver
Creating network "part2_backend" with the default driver
Creating part2_gateway_1
Creating part2_db_1
Creating part2_api_1
```

2. Let's examine if all the services are running.
```
docker-compose ps
```
You will see something similar to the results below:
```
     Name               Command          State                          Ports                        
----------------------------------------------------------------------------------------------------
part2_api_1       ./start.sh             Up       0.0.0.0:3000->3000/tcp                             
part2_db_1        /run.sh                Up       0.0.0.0:27017->27017/tcp, 0.0.0.0:28017->28017/tcp 
part2_gateway_1   nginx -g daemon off;   Exit 1                                                      
```
This means that the _db_ and _api_ services started properly, but the _gateway_ service did not.

### Determine Problems
So let's see if we can look at the log files for the _gateway_ service and determine what went wrong.

1. Execute the command below to get the logs for the _gateway_ service
```
docker-compose logs gateway
```

2. Exampine the results
```
Attaching to part2_gateway_1
gateway_1  | 2016/10/22 15:25:03 [emerg] 1#1: host not found in upstream "api" in /etc/nginx/nginx.conf:54
gateway_1  | nginx: [emerg] host not found in upstream "api" in /etc/nginx/nginx.conf:54
```

The _gateway_ service could not connect to the _api_ service. This means that the container had not yet started and the Nginx process could not connect to the host and it failed. If you notice, in the _docker_compose.yml_ file we did not specify a dependecy from _gateway_ on _api_ service.

3. Let's go ahead and start the _gateway_ service
```
docker-compose start gateway
```
If all goes well, you will see a message like below:
```
Starting gateway ... done
```
Let's make sure that everything is running:
```
docker-compose ps
```

And the result should be something like below, where all the services have an **Up** state:
```
     Name               Command          State                         Ports                        
---------------------------------------------------------------------------------------------------
part2_api_1       ./start.sh             Up      0.0.0.0:3000->3000/tcp                             
part2_db_1        /run.sh                Up      0.0.0.0:27017->27017/tcp, 0.0.0.0:28017->28017/tcp 
part2_gateway_1   nginx -g daemon off;   Up      443/tcp, 0.0.0.0:8080->80/tcp                      
```

## Invoke the API
The application is up and running, so let's see if we can invoke the API on the Nginx server and go all the way to the database and back.

1. Let's first see if there are any Cars in the database
```bash
curl "http://localhost:8080/api/Cars"
```

2. You will see an empty array as the response, which means we don't have any Cars
```
[]
```

> **Note:** The response does not have a new line at the end of it, so the prompt shows up right at the end of the response, which makes it harder to read. You can always redirect your responses to a file or more command if you like further clarity.

3. Let's invoke a POST API call and add a Car
```bash
curl -X POST "http://localhost:8080/api/Cars" -d '{ "model": "Focus", "make": "Ford", "year": 2016, "miles": 1000 }'
```

We used the following JSON object as the input to the API call
```json
{
	"model": "Focus",
	"make": "Ford",
	"year": 2016,
	"miles": 1000
}
```
You should see a result similar to below, with a different ID perhaps:
```
{"id":"580b87f79b70522c0037824e","{ \"model\": \"Focus\", \"make\": \"Ford\", \"year\": 2016, \"miles\": 1000 }":""}
```

4. To verify that the entry was created, you can repeat step 1 to get all the cars, or you can get the specific car with its id.
> **Note:** replace the value of the id below (580b87f79b70522c0037824e), with the ID you received from your call above
```bash
curl "http://localhost:8080/api/Cars/580b87f79b70522c0037824e"
```

## More Docker Compose Commands
Now that we have validated that the application is running correctly, we can look at a few more commands.

1. Stop the Compose application
```bash
docker-compose stop
```

You will see a result like below:
```
Stopping part2_api_1 ... done
Stopping part2_db_1 ... done
Stopping part2_gateway_1 ... done
```

2. Validate the services are stopped
```bash
docker-compose ps
```

You will see:
```
     Name               Command           State     Ports 
---------------------------------------------------------
part2_api_1       ./start.sh             Exit 137         
part2_db_1        /run.sh                Exit 137         
part2_gateway_1   nginx -g daemon off;   Exit 0           
```

The stop command only stops the running containers, it does not remove them, which means you can restart them by a _start_ command.

3. Stop and Remove the application
```
docker-compose down
``` 

This command will first stop and then remove the containers. You will see results similar to below:
```
Removing part2_api_1 ... done
Removing part2_db_1 ... done
Removing part2_gateway_1 ... done
Removing network part2_frontend
Removing network part2_backend
```

4. Verify that there are no services running
```
docker-compose ps
```

Results
```
Name   Command   State   Ports 
------------------------------
```

## References

### Docker Compose documentation

[https://docs.docker.com/compose/overview/](https://docs.docker.com/compose/overview/)

### Compose File References
[https://docker.github.io/compose/compose-file/](https://docker.github.io/compose/compose-file/)

### Command Line References
[https://docker.github.io/compose/reference/](https://docker.github.io/compose/reference/)
