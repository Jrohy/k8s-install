# k8s-install
## [中文](README.md)  [English](README_EN.md)

auto install latest docker && k8s  
support **CentOS 7+/Debian 9+/Ubuntu 16+**

three step to quickly create k8s Cluster

## 1. init master node
master node run:  
```
# use flannel network
source <(curl -sL https://k8s-install.netlify.app/install.sh) --flannel
```
or 

```
# use calico network
source <(curl -sL https://k8s-install.netlify.app/install.sh) --calico
```

it will init master node and create 'kubeadm join xxx' command

## 2. install slave node
slave node run
```
source <(curl -sL https://k8s-install.netlify.app/install.sh)
```

## 3. join cluster
slave node run first step left command 'kubeadm join xxx'

---
u can also set machine hostname by pass '--hostname xxx' param, for example:
```
source <(curl -sL https://k8s-install.netlify.app/install.sh) --flannel --hostname master_test
```
tip: every machine must have different hostname to create cluster

## check result
master node run:
1. `kubectl get nodes`, all node status is ready
2. `kubectl get pods -n kube-system`, all pod status is 1/1

all check pass means create k8s cluster success!

## command line
```
k8s_install.sh [-h|--help] [options]
    --flannel                    use flannel network, and set this node as master
    --calico                     use calico network, and set this node as master
    --hostname [HOSTNAME]        set hostname
```