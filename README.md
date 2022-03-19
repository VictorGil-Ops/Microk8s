# micro8ks

#### Installation

```bash

sudo snap install microk8s --classic 

```

#### Check the status while Kubernetes starts 

```bash

microk8s status --wait-ready

```

#### Turn on the services you want

> microk8s enable --help for a list of available services and optional features. 

```bash

microk8s enable dashboard dns registry istio 

```

####  Start using Kubernetes 

```bash

microk8s kubectl get all --all-namespaces 

```

####  Access the Kubernetes dashboard 

```bash

microk8s dashboard-proxy

```

#### Start and stop Kubernetes

```bash

microk8s start/stop

```

# Install kubectl

[`https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/`]

### Install kubectl binary with curl on Linux

```bash

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

```

#### Install using other package management 

```bash

snap install kubectl --classic
kubectl version --client

```

# Verify kubectl configuration

```bash

kubectl cluster-info

```
