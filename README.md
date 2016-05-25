# Docker ELK stack configured for ECS logs

[![Join the chat at https://gitter.im/deviantony/docker-elk](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/deviantony/docker-elk?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Shamelessly forked from  deviantony/docker-elk

Run the latest version of the ELK (Elasticseach, Logstash, Kibana) stack with Docker and Docker-compose to grok ECS log files


## Additions to support ECS docker logs
1. **name_the_container_logs.sh** -- a shell script that you can run as a service on your ECS instances. It creates a symbolic link to each container's log file and embeds the ecs-container-name, ecs-task-family and ecs-task-revision, ecs-image-name and ecs-image-version (aka tag)
2. **grok patterns** for docker logs

## Additions to Make Testing Easier
1. **a /logs volume** mounted from the current working directory -- just drop files in, and they'll be stashed into Kibana
2. **-r Option to logstash** so you can change the logstash.conf file without having to restart your containers


# Results

##Kibana logging will have extra ECS fields:

* docker_log_message     
* docker_log_stream      
* docker_log_timestamp   
* ecs_container_name     
* ecs_image_basename     
* ecs_image_tag      
* ecs_task_definition_family
* ecs_task_definition_version 

##Testing grok rules is easier

1. just drop your log files into ./logs and logstash will slurp them up.
2. Edit the logstash.conf file, and logstash will reload it
3. `make run` starts it up, feeds logs/initial-input.log into logstash, and opens Kibana in a browser


# Configuring Your Logstash indexer
On ECS, you will probably want to use filebeat to forward logfiles to logstash.

##Add the docker container logs to Filebeat like this:

    filebeat:
      prospectors:
        paths:
          - "/var/lib/docker/containers/*/*.nlog"
        fields:
          log_type: docker


##Add these rules to your Logstash indexer
  
    filter {
       grok {
          match => [ "message", "\{\"log\":\"%{GREEDYDATA:docker_log_message}\",\"stream\":\"%{WORD:docker_log_stream}\",\"time\":\"%{TIMESTAMP_ISO8601:docker_log_timestamp}\"\}" ]
       }
       grok {
            match => [ "source", "%{GREEDYDATA}\/%{GREEDYDATA:ecs_container_name}@%{GREEDYDATA:ecs_task_definition_family}@%{GREEDYDATA:ecs_task_definition_version}@%{GREEDYDATA:ecs_image_basename}@%{GREEDYDATA:ecs_image_tag}.nlog" ]
       }
    }

Using two separate grok filters allows you to match both the "message" and the "source"

# SEE deviantony/docker-elk for the REST  -- everything below is just a COPY

It will give you the ability to analyze any data set by using the searching/aggregation capabilities of Elasticseach and the visualization power of Kibana.

Based on the official images:

* [elasticsearch](https://registry.hub.docker.com/_/elasticsearch/)
* [logstash](https://registry.hub.docker.com/_/logstash/)
* [kibana](https://registry.hub.docker.com/_/kibana/)

# Requirements

## Setup

1. Install [Docker](http://docker.io).
2. Install [Docker-compose](http://docs.docker.com/compose/install/).
3. Clone this repository

## SELinux

On distributions which have SELinux enabled out-of-the-box you will need to either re-context the files or set SELinux into Permissive mode in order for docker-elk to start properly.
For example on Redhat and CentOS, the following will apply the proper context:

````bash
.-root@centos ~
-$ chcon -R system_u:object_r:admin_home_t:s0 docker-elk/
````

# Usage

Start the ELK stack using *docker-compose*:

```bash
$ docker-compose up
```

You can also choose to run it in background (detached mode):

```bash
$ docker-compose up -d
```

Now that the stack is running, you'll want to inject logs in it. The shipped logstash configuration allows you to send content via tcp:

```bash
$ nc localhost 5000 < /path/to/logfile.log
```

And then access Kibana UI by hitting [http://localhost:5601](http://localhost:5601) with a web browser.

*NOTE*: You'll need to inject data into logstash before being able to create a logstash index in Kibana. Then all you should have to do is to
hit the create button.

See: https://www.elastic.co/guide/en/kibana/current/setup.html#connect

You can also access:
* Sense: [http://localhost:5601/app/sense](http://localhost:5601/app/sense)

*NOTE*: In order to use Sense, you'll need to query the IP address associated to your *network device* instead of localhost.

By default, the stack exposes the following ports:
* 5000: Logstash TCP input.
* 9200: Elasticsearch HTTP
* 9300: Elasticsearch TCP transport
* 5601: Kibana

*WARNING*: If you're using *boot2docker*, you must access it via the *boot2docker* IP address instead of *localhost*.

*WARNING*: If you're using *Docker Toolbox*, you must access it via the *docker-machine* IP address instead of *localhost*.

# Configuration

*NOTE*: Configuration is not dynamically reloaded, you will need to restart the stack after any change in the configuration of a component.

## How can I tune Kibana configuration?

The Kibana default configuration is stored in `kibana/config/kibana.yml`.

## How can I tune Logstash configuration?

The logstash configuration is stored in `logstash/config/logstash.conf`.

The folder `logstash/config` is mapped onto the container `/etc/logstash/conf.d` so you
can create more than one file in that folder if you'd like to. However, you must be aware that config files will be read from the directory in alphabetical order.

## How can I specify the amount of memory used by Logstash?

The Logstash container use the *LS_HEAP_SIZE* environment variable to determine how much memory should be associated to the JVM heap memory (defaults to 500m).

If you want to override the default configuration, add the *LS_HEAP_SIZE* environment variable to the container in the `docker-compose.yml`:

```yml
logstash:
  image: logstash:latest
  command: logstash -f /etc/logstash/conf.d/logstash.conf
  volumes:
    - ./logstash/config:/etc/logstash/conf.d
  ports:
    - "5000:5000"
  links:
    - elasticsearch
  environment:
    - LS_HEAP_SIZE=2048m
```

## How can I enable a remote JMX connection to Logstash?

As for the Java heap memory, another environment variable allows to specify JAVA_OPTS used by Logstash. You'll need to specify the appropriate options to enable JMX and map the JMX port on the docker host.

Update the container in the `docker-compose.yml` to add the *LS_JAVA_OPTS* environment variable with the following content (I've mapped the JMX service on the port 18080, you can change that), do not forget to update the *-Djava.rmi.server.hostname* option with the IP address of your Docker host (replace **DOCKER_HOST_IP**):

```yml
logstash:
  image: logstash:latest
  command: logstash -f /etc/logstash/conf.d/logstash.conf
  volumes:
    - ./logstash/config:/etc/logstash/conf.d
  ports:
    - "5000:5000"
    - "18080:18080"
  links:
    - elasticsearch
  environment:
    - LS_JAVA_OPTS=-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.port=18080 -Dcom.sun.management.jmxremote.rmi.port=18080 -Djava.rmi.server.hostname=DOCKER_HOST_IP -Dcom.sun.management.jmxremote.local.only=false
```

## How can I tune Elasticsearch configuration?

The Elasticsearch container is using the shipped configuration and it is not exposed by default.

If you want to override the default configuration, create a file `elasticsearch/config/elasticsearch.yml` and add your configuration in it.

Then, you'll need to map your configuration file inside the container in the `docker-compose.yml`. Update the elasticsearch container declaration to:

```yml
elasticsearch:
  build: elasticsearch/
  command: elasticsearch -Des.network.host=_non_loopback_
  ports:
    - "9200:9200"
  volumes:
    - ./elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml
```

You can also specify the options you want to override directly in the command field:

```yml
elasticsearch:
  build: elasticsearch/
  command: elasticsearch -Des.network.host=_non_loopback_ -Des.cluster.name: my-cluster
  ports:
    - "9200:9200"
```

# Storage

## How can I store Elasticsearch data?

The data stored in Elasticsearch will be persisted after container reboot but not after container removal.

In order to persist Elasticsearch data even after removing the Elasticsearch container, you'll have to mount a volume on your Docker host. Update the elasticsearch container declaration to:

```yml
elasticsearch:
  build: elasticsearch/
  command: elasticsearch -Des.network.host=_non_loopback_
  ports:
    - "9200:9200"
  volumes:
    - /path/to/storage:/usr/share/elasticsearch/data
```

This will store elasticsearch data inside `/path/to/storage`.
