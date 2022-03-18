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
