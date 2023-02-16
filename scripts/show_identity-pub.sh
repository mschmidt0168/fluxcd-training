#! /bin/bash

set -e

FILENAME=$1

if grep -q sops $FILENAME; then
    sops -d --extract '["data"]["identity.pub"]' $FILENAME | base64 -d
else
    yq e '.data."identity.pub"' $FILENAME | base64 -d 
fi