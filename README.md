# MicroK8s common use

`https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s?&_ga=2.198964079.159365322.1647560184-1468234753.1647560184#1-overview`

## Installation

```bash

sudo snap install microk8s --classic 

```

### Check the status while Kubernetes starts

```bash

microk8s status --wait-ready

```

### Turn on the services you want

> microk8s enable --help for a list of available services and optional features.

```bash

microk8s enable dashboard dns registry istio 

```

### Start using Kubernetes

```bash

microk8s kubectl get all --all-namespaces 

```

### Access the Kubernetes dashboard

```bash

microk8s dashboard-proxy

```

### Start and stop Kubernetes

```bash

microk8s start/stop

```

## Install kubectl

[`https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/`]

### Install kubectl binary with curl on Linux

```bash

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

```

### Install using other package management

```bash

snap install kubectl --classic
kubectl version --client

```

### Verify kubectl configuration

```bash

kubectl cluster-info

```

### Change user and context

```bash

kubectl config set-context microk8s --user=admin --namespace=default

```

## Create cert for user

```bash

openssl genrsa -out victor.key 2048 

openssl req -new -key victor.key -out victor.csr -subj "/CN=victor/O=office"

CA_LOCATION=/var/snap/microk8s/current/certs/

openssl x509 -req -in victor.csr -CA $CA_LOCATION/ca.crt -CAkey $CA_LOCATION/ca.key -CAcreateserial -out victor.crt -days 500

```
