#!/bin/bash

exit_script=0

if [ -z $USE_BUILDAH ] || [ "$USE_BUILDAH" != "true" ]
then
    if ! docker --version > /dev/null 2>&1
    then
        echo "Error: 'docker' command is not installed or not available on the path"
        exit_script=1
    fi
fi

if ! yq --version > /dev/null 2>&1
then
    echo "Error: 'yq' command is not installed or not available on the path"
    exit_script=1
fi

if ! jq --version > /dev/null 2>&1
then
    echo "Error: 'jq' command is not installed or not available on the path"
    exit_script=1
fi

if [ $exit_script != 0 ]
then
    echo "Error: Some required dependencies are missing, exiting script"
    exit 1
fi

