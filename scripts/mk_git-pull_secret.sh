#!/bin/bash

set -e

NAME=$1
WORKDIR=$(dirname $0)

mkdir -p $WORKDIR/$NAME

ssh-keygen -q -N "" -C "development@$NAME" -f $WORKDIR/$NAME/identity
ssh-keyscan  github.com > $WORKDIR/$NAME/known_hosts

kubectl create secret generic git-pull-secret \
    --from-file=$WORKDIR/$NAME/identity \
    --from-file=$WORKDIR/$NAME/identity.pub \
    --from-file=$WORKDIR/$NAME/known_hosts \
    --dry-run=client -o yaml | \
  kubectl patch --local -f- --type=json \
    -p='[{"op": "remove", "path": "/metadata/creationTimestamp"}]' -o yaml

rm $WORKDIR/$NAME/identity
rm $WORKDIR/$NAME/identity.pub
rm $WORKDIR/$NAME/known_hosts
rmdir $WORKDIR/$NAME