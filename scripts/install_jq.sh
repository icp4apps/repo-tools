#!/bin/bash

cd /tmp
curl -L -o jq-linux64 https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
sudo cp ./jq-linux64 /usr/local/bin/jq
sudo chmod 755 /usr/local/bin/jq

jq --version