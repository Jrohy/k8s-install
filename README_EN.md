# k8s-install
## [中文](README.md)  [English](README_EN.md)

auto install latest docker && k8s  
support **CentOS 7/Debian 9+/Ubuntu 16+**

three step to quickly create k8s Cluster

## 1. init master node
master node run:  
```
# use flannel network
source <(curl -sL https://git.io/fjXVF) --flannel
```
or 

```
# use calico network
source <(curl -sL https://git.io/fjXVF) --calico
```

it will init master node and create 'kubeadm join xxx' command

## 2. install slave node
slave node run
```
source <(curl -sL https://git.io/fjXVF)
```

## 3. join cluster
slave node run first step left command 'kubeadm join xxx'

---
u can also set machine hostname by pass '--hostname xxx' param, for example:
```
source <(curl -sL https://git.io/fjXVF) --flannel --hostname master_test
```
tip: every machine must have different hostname to create cluster

#### check result: run `kubectl get nodes` in master node, all ready mean success