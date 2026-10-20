# Simple demo for Kubernetes Ingress

Expose an application with an `Ingress`, on vanilla Kubernetes and on OpenShift.

| Platform | Script | Ingress controller |
|---|---|---|
| Kubernetes (kind, kubeadm) | `setup.sh` | [Traefik](https://doc.traefik.io/traefik/), installed with Helm |
| OpenShift | `openshift-setup.sh` | built in: the `Ingress` is turned into a `Route` |

> [!NOTE]
> The community [ingress-nginx](https://github.com/kubernetes/ingress-nginx) controller has been retired, it no longer gets releases nor security fixes.
> The `Ingress` API itself is still supported but frozen: new features go to the [Gateway API](https://gateway-api.sigs.k8s.io/), see [demo-apigateway](https://github.com/k8s-school/demo-apigateway).

## Pre-requisites

- An up and running Kubernetes or OpenShift cluster
- Helm and OpenSSL, for Kubernetes

## Kubernetes

```bash
git clone https://github.com/k8s-school/demo-ingress
cd demo-ingress
# Install Traefik and the application
./setup.sh
# Also create the Ingress, with TLS, and test it
./setup.sh -s
```

Traefik is exposed with a `NodePort` Service, since the demo runs on a bare cluster with no cloud LoadBalancer.
It creates the `IngressClass` `traefik`, used by `example-ingress.yaml`.

### HTTPS Support

The setup script:

1. Generates a self-signed certificate using `generate-certs.sh`
2. Creates a Kubernetes TLS secret with the certificate
3. Configures the ingress to use TLS

You can also generate the certificate manually:

```bash
./generate-certs.sh [domain-name]
```

Default domain is `hello-world.info`. Certificates are stored in `./certs/` directory.

### Accessing the application

Add `<node-ip> hello-world.info` to `/etc/hosts`, the script prints the line. Then:

- **HTTP**: `curl hello-world.info:<node-port>`
- **HTTPS**: `curl -k https://hello-world.info:<https-node-port>`

The `-k` flag ignores the self-signed certificate warnings.

## OpenShift

```bash
./openshift-setup.sh
```

There is no ingress controller to install: the `openshift-default` `IngressClass` is handled by the ingress-to-route controller, which creates one `Route` per `Ingress` rule.
The HAProxy router serves the `Route`, with TLS edge termination (annotation `route.openshift.io/termination`).

```bash
oc get ingress,route -n ingress-app
```

The script targets [OpenShift Local (CRC)](https://developers.redhat.com/products/openshift-local/overview) (`*.apps-crc.testing`), change the host in `example-ingress-openshift.yaml` for another cluster.
