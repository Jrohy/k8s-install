# k8s-install
## [中文](README.md)  [English](README_EN.md)

最新版 k8s 快速搭建脚本, 自适应国内外网络环境, 无法连接谷歌源自动切换成国内源(aliyun)来安装  
支持 **CentOS 7+/Debian 9+/Ubuntu 16+**

三步即可快速搭建k8s集群

## 1. master节点初始化
master 节点服务器运行:  
```
# use flannel network
source <(curl -sL https://k8s-install.netlify.app/install.sh) --flannel
```
或者

```
# use calico network
source <(curl -sL https://k8s-install.netlify.app/install.sh) --calico
```

运行脚本会自动初始化(kubeadm init), 最后生成 'kubeadm join'命令

## 2. slave节点安装
slave 节点服务器运行:
```
source <(curl -sL https://k8s-install.netlify.app/install.sh)
```

## 3. 加入集群
slave 节点运行第一步生成的 'kubeadm join xxx'

---

可以加入参数'--hostname xxx'来同时设置服务器的hostname, 举个栗子:
```
source <(curl -sL https://k8s-install.netlify.app/install.sh) --flannel --hostname master_test
```
PS: 所有机器的hostname不一样集群才能搭建成功

## 验证结果
在master服务器上运行:
1. `kubectl get nodes`, 所有节点都是ready
2. `kubectl get pods -n kube-system`, 所有Pod READY状态都是1/1

同时符合以上两点即代表k8s集群搭建成功!

## 命令行参数列表
```
k8s_install.sh [-h|--help] [options]
    --flannel               使用flannel网络, 同时设置当前服务器为Master节点
    --calico                使用calico网络, 同时设置当前服务器为Master节点
    --hostname [hostname]   设置服务器hostname
    -v, --version [version] 安装特定版本的k8s
```

## 注意
k8s 从1.24版本开始默认不支持docker, 得使用[cri-dockerd](https://github.com/Mirantis/cri-dockerd)才能支持, 因为cri-dockerd国内vps不好安装(从github下载文件), 所以从k8s 1.24版本开始改为用containerd来起k8s(还是会安装docker, 只不过用的containerd是用docker安装后带来的版本)
