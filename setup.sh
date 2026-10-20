#!/bin/bash

# Ingress demo with the Traefik ingress controller
# See https://doc.traefik.io/traefik/getting-started/install-traefik/
# and https://kubernetes.io/docs/concepts/services-networking/ingress/
set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/conf.sh

usage() {
  cat << EOD

Usage: `basename $0` [options]

  Available options:
    -h         this message
    -s         run exercice and solution

Run ingress exercice
EOD
}

INGRESS_FULL=false

# get the options
while getopts hs c ; do
    case $c in
	    h) usage ; exit 0 ;;
	    s) INGRESS_FULL=true ;;
	    \?) usage ; exit 2 ;;
    esac
done
shift `expr $OPTIND - 1`

if [ $# -ne 0 ] ; then
    usage
    exit 2
fi

NSAPP="ingress-app"
NODE1_IP=$(kubectl get nodes --selector="! node-role.kubernetes.io/master" \
    -o=jsonpath='{.items[0].status.addresses[0].address}')

# Run on kubeadm cluster
# see "kubernetes in action" p391
kubectl delete ns -l "demo=ingress"
kubectl create namespace "$ingress_ns"
kubectl create namespace "$NSAPP"
kubectl label ns "$ingress_ns" "demo=ingress"
kubectl label ns "$NSAPP" "demo=ingress"

ink "Install Traefik ingress controller, exposed via NodePort (no cloud LoadBalancer on this cluster)"
helm upgrade --install traefik traefik \
  --repo https://traefik.github.io/charts --version "$traefik_chart_version" \
  --namespace "$ingress_ns" \
  --set service.type=NodePort

ink "Deploy application"
kubectl create deployment web -n "$NSAPP" --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment web -n "$NSAPP" --port=8080
kubectl  wait -n "$NSAPP" --for=condition=available deployment web

ink "Wait for Traefik to be up and running (alternatively, use helm --wait)"
kubectl wait --for=condition=available deployment -n "$ingress_ns" -l app.kubernetes.io/instance=traefik-"$ingress_ns"
kubectl get ingressclass

echo "INFO: to access the application by name, add '$NODE1_IP hello-world.info' to /etc/hosts"

if [ "$INGRESS_FULL" = false ]
then
    exit 0
fi

ink "Generate self-signed certificates for HTTPS"
$DIR/generate-certs.sh hello-world.info

ink "Create TLS secret from generated certificates"
kubectl create secret tls hello-world-tls -n "$NSAPP" \
    --key $DIR/certs/tls.key \
    --cert $DIR/certs/tls.crt

ink "Create ingress route with TLS"
kubectl apply -n "$NSAPP" -f $DIR/example-ingress.yaml
kubectl get -n "$NSAPP" ingress

ink "Access the application"
# Match by .port, the entrypoint ports exposed by the chart (80/443)
NODE_PORT=$(kubectl get svc traefik -n "$ingress_ns" -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
HTTPS_NODE_PORT=$(kubectl get svc traefik -n "$ingress_ns" -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')

echo "INFO: access the application via ingress"
echo "HTTP:  curl hello-world.info:$NODE_PORT"
echo "HTTPS: curl -k https://hello-world.info:$HTTPS_NODE_PORT"
echo ""
# --resolve avoids depending on /etc/hosts
curl -sS --fail --resolve "hello-world.info:$NODE_PORT:$NODE1_IP" hello-world.info:$NODE_PORT
echo ""
echo "Testing HTTPS endpoint (ignoring self-signed certificate):"
curl -sS --fail -k --resolve "hello-world.info:$HTTPS_NODE_PORT:$NODE1_IP" https://hello-world.info:$HTTPS_NODE_PORT
