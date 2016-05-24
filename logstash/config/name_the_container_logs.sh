#!/bin/bash

#
# Create symbolic links to the container's log files named after the containers name
# so that filebeat will report the container_name, task_definition_version to elastic search and Kibana
#
# FORMAT: ${container_name}@${task_definition_family}@${task_definition_version}@${image_basename}@${tag}.nlog

CONTAINER_DIR=/var/lib/docker/containers

name_the_container() {
    container_id=$1

    (
        set -ex
        [ -d "$CONTAINER_DIR/$container_id" ] || return
        
        cd "$CONTAINER_DIR/$container_id" 

        # if we've already created a named-log file, then we're done with this directory
        [ -f *.nlog ] && return
        
        container_name=$(/usr/bin/docker inspect --format '{{ index .Config.Labels "com.amazonaws.ecs.container-name" }}' $container_id 2>/dev/null)
        if [ -n "$container_name" ]; then
            #
            #  This is an ECS Task or Service -- use the Labels to name it
            #
            container_name=$(basename $container_name)
            task_definition_version=$(/usr/bin/docker inspect --format '{{ index .Config.Labels "com.amazonaws.ecs.task-definition-version" }}' $container_id 2>/dev/null) 
            [ -n "$task_definition_version" ] || return

            task_definition_family=$(/usr/bin/docker inspect --format '{{ index .Config.Labels "com.amazonaws.ecs.task-definition-family" }}' $container_id 2>/dev/null) 
            [ -n "$task_definition_family" ] || return

        else
            #
            #  This is some other container (possibly the amazone-ecs-agent itself) started by chef or some other means.
            #  If it were started by the amazon-ecs-agent, it would have Labels for the container-name, task-definition-version and family
            #
            container_name=$(/usr/bin/docker inspect --format '{{ .Name }}' $container_id 2>/dev/null)
            [ -n "$container_name" ] || return
            container_name=$(basename $container_name)
            task_definition_version=0
            task_definition_family=none
        fi

        image=$(docker inspect --format '{{ .Config.Image }}' $container_id)
        [ -n "$image" ] || return

        repository=$(echo $image | cut -d: -f1)
        image_basename=$(basename $repository)
        tag=$(echo $image | cut -d: -f2-)
        log_file_name="${container_name}@${task_definition_family}@${task_definition_version}@${image_basename}@${tag}.nlog"


        [ -f "$log_file_name" ] && return

        ln -sf ${container_id}-json.log $log_file_name
    )
}


name_the_containers() {
    cd $CONTAINER_DIR
    inotifywait --event create --monitor . | 
        while read watched_dir event container_id
        do
            # The docker engine "saves" our symlink files when it destroys container directories, by moving them up 
            # to the parent directory (here) so we need to periodically remove these artifacts
            rm -fv *.nlog
            case $container_id in
                [a-f0-9][a-f0-9][a-f0-9]*)      [ -d "$CONTAINER_DIR/$container_id" ] && name_the_container $container_id;;
                *)                              true;;
            esac
        done    
}


# run forever
while true
do
    name_the_containers
    sleep 2
done

