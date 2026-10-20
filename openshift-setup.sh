#!/bin/bash

# Ingress demo on OpenShift: no ingress controller to install, the ingress-to-route
# controller turns each Ingress into a Route served by the HAProxy router
# See the OpenShift documentation: Networking > Configuring routes > Creating a route through an Ingress object
set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

NSAPP="ingress-app"

# Run on openshift cluster
kubectl delete project -l "kubernetes.io/metadata.name=$NSAPP"
oc new-project "$NSAPP"

# Deploy application
kubectl create deployment web -n "$NSAPP" --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment web -n "$NSAPP" --port=8080
kubectl  wait -n "$NSAPP" --for=condition=available deployment web

# Create ingress route
kubectl get ingressclasses
kubectl apply -n "$NSAPP" -f $DIR/example-ingress-openshift.yaml
kubectl get -n "$NSAPP" ingress
kubectl get -n "$NSAPP" route

# The router needs a few seconds to load the new Route
curl -sS --fail -k --retry 10 --retry-all-errors --retry-delay 2 https://hello-world.apps-crc.testing
