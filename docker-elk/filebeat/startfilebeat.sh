#!/bin/bash
echo "Start filebeat ......"
sudo ./filebeat -e -c /workspace/app/filebeat/yaml/filebeat.yml &
