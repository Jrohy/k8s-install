# k8s-install
# [中文](README.md)  [English](README_EN.md)

最新版 k8s 快速搭建脚本, 自适应国内外网络环境, 无法连接谷歌源自动切换成国内源(aliyun)来安装  
支持 **CentOS 7/Debian 9+/Ubuntu 16+**

三步即可快速搭建k8s集群

## 1. master节点初始化
master 节点服务器运行:  
```
# use flannel network
source <(curl -sL https://git.io/fjXVF) --flannel
```
或者

```
# use calico network
source <(curl -sL https://git.io/fjXVF) --calico
```

运行脚本会自动初始化(kubeadm init), 最后生成 'kubeadm join'命令

## 2. slave节点安装
slave 节点服务器运行:
```
source <(curl -sL https://git.io/fjXVF)
```

## 3. 加入集群
slave 节点运行第一步生成的 'kubeadm join xxx'

---

可以加入参数'--hostname xxx'来同时设置服务器的hostname, 举个栗子:
```
source <(curl -sL https://git.io/fjXVF) --flannel --hostname master_test
```