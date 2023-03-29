#!/bin/bash
# Author: Jrohy
# Github: https://github.com/Jrohy/k8s-install

# cancel centos alias
[[ -f /etc/redhat-release ]] && unalias -a

#######color code########
red="31m"      
green="32m"  
yellow="33m" 
blue="36m"
fuchsia="35m"

google_urls=(
    packages.cloud.google.com
    k8s.gcr.io
    gcr.io
)

mirror_source="registry.cn-hangzhou.aliyuncs.com/google_containers"

can_google=1

is_master=0

network=""

k8s_version=""

color_echo(){
    echo -e "\033[$1${@:2}\033[0m"
}

ip_is_connect(){
    ping -c2 -i0.3 -W1 $1 &>/dev/null
    if [ $? -eq 0 ];then
        return 0
    else
        return 1
    fi
}

run_command(){
    echo ""
    local command=$1
    echo -e "\033[32m$command\033[0m"
    echo $command|bash
}

set_hostname(){
    local hostname=$1
    if [[ $hostname =~ '_' ]];then
        color_echo $yellow "hostname can't contain '_' character, auto change to '-'.."
        hostname=`echo $hostname|sed 's/_/-/g'`
    fi
    echo "set hostname: `color_echo $blue $hostname`"
    echo "127.0.0.1 $hostname" >> /etc/hosts
    run_command "hostnamectl --static set-hostname $hostname"
}

#######get params#########
while [[ $# > 0 ]];do
    case "$1" in
        --hostname)
        set_hostname $2
        shift
        ;;
        -v|--version)
        k8s_version=`echo "$2"|sed 's/v//g'`
        echo "prepare install k8s version: $(color_echo $green $k8s_version)"
        shift
        ;;
        --flannel)
        echo "use flannel network, and set this node as master"
        network="flannel"
        is_master=1
        ;;
        --calico)
        echo "use calico network, and set this node as master"
        network="calico"
        is_master=1
        ;;
        -h|--help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "   --flannel                    use flannel network, and set this node as master"
        echo "   --calico                     use calico network, and set this node as master"
        echo "   --hostname [hostname]        set hostname"
        echo "   -v, --version [version]:     install special version k8s"
        echo "   -h, --help:                  find help"
        echo ""
        exit 0
        shift # past argument
        ;; 
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done
#############################

check_sys() {
    #检查是否为Root
    [ $(id -u) != "0" ] && { color_echo ${red} "Error: You must be root to run this script"; exit 1; }

    #检查CPU核数
    [[ `cat /proc/cpuinfo |grep "processor"|wc -l` == 1 && $is_master == 1 ]] && { color_echo ${red} "master node cpu number should be >= 2!"; exit 1;}

    #检查系统信息
    if [[ -e /etc/redhat-release ]];then
        if [[ $(cat /etc/redhat-release | grep Fedora) ]];then
            os='Fedora'
            package_manager='dnf'
        else
            os='CentOS'
            package_manager='yum'
        fi
    elif [[ $(cat /etc/issue | grep Debian) ]];then
        os='Debian'
        package_manager='apt-get'
    elif [[ $(cat /etc/issue | grep Ubuntu) ]];then
        os='Ubuntu'
        package_manager='apt-get'
    else
        color_echo ${red} "Not support os, Please reinstall os and retry!"
        exit 1
    fi

    [[ `cat /etc/hostname` =~ '_' ]] && set_hostname `cat /etc/hostname`

    echo "Checking machine network(access google)..."
    for ((i=0;i<${#google_urls[*]};i++))
    do
        ip_is_connect ${google_urls[$i]}
        if [[ ! $? -eq 0 ]]; then
            color_echo ${yellow} "server can't access google source, switch to chinese source(aliyun).."
            can_google=0
            break	
        fi
    done
}

#安装依赖
install_dependent(){
    if [[ ${os} == 'CentOS' || ${os} == 'Fedora' ]];then
        ${package_manager} install bash-completion -y
    else
        ${package_manager} update
        ${package_manager} install bash-completion apt-transport-https -y
    fi
}

setup_docker(){
    ## 修改cgroupdriver
    if [[ ! -e /etc/docker/daemon.json || -z `cat /etc/docker/daemon.json|grep systemd` ]];then
        ## see https://kubernetes.io/docs/setup/production-environment/container-runtimes/
        mkdir -p /etc/docker
        if [[ ${os} == 'CentOS' || ${os} == 'Fedora' ]];then
            if [[ $can_google == 1 ]];then
                cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOF
            else
                cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com"
    ]
}
EOF
            fi
        else
            if [[ $can_google == 1 ]];then
                cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF
            else
                cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com"
    ]
}
EOF
            fi
        fi
        systemctl restart docker
        if [ $? -ne 0 ];then
            rm -f /etc/docker/daemon.json
            if [[ $can_google == 0 ]];then
                cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com"
    ]
}
EOF
            fi
            systemctl restart docker
        fi
    fi
}

setup_containerd() {
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd
}

prepare_work() {
    ## Centos设置
    if [[ ${os} == 'CentOS' || ${os} == 'Fedora' ]];then
        if [[ `systemctl list-units --type=service|grep firewalld` ]];then
            systemctl disable firewalld.service
            systemctl stop firewalld.service
        fi
        cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
        sysctl --system
    fi
    ## 禁用SELinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
    ## 关闭swap
    swapoff -a
    sed -i 's/.*swap.*/#&/' /etc/fstab

    ## 安装最新版docker
    if [[ ! $(type docker 2>/dev/null) ]];then
        color_echo ${yellow} "docker no install, auto install latest docker..."
        source <(curl -sL https://docker-install.netlify.app/install.sh) -s
    fi

    setup_docker

    setup_containerd
}

install_k8s_base() {
    if [[ $os == 'Fedora' || $os == 'CentOS' ]];then
        cat>>/etc/yum.repos.d/kubrenetes.repo<<EOF
[kubernetes]
name=Kubernetes Repo
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
EOF
    else
        curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
        echo "deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
        ${package_manager} update
    fi

    if [[ -z $k8s_version ]];then
        ${package_manager} install -y kubelet kubeadm kubectl
    else
        if [[ $package_manager == "apt-get" ]];then
            install_version=`apt-cache madison kubectl|grep $k8s_version|cut -d \| -f 2|sed 's/ //g'`
            ${package_manager} install -y kubelet=$install_version kubeadm=$install_version kubectl=$install_version
        else
            ${package_manager} install -y kubelet-$k8s_version kubeadm-$k8s_version kubectl-$k8s_version
        fi
    fi
    systemctl enable kubelet && systemctl start kubelet

    #命令行补全
    [[ -z $(grep kubectl ~/.bashrc) ]] && echo "source <(kubectl completion bash)" >> ~/.bashrc
    [[ -z $(grep kubeadm ~/.bashrc) ]] && echo "source <(kubeadm completion bash)" >> ~/.bashrc
    source ~/.bashrc
    k8s_version=$(kubectl version --output=yaml|grep gitVersion|awk 'NR==1{print $2}')
    k8s_minor_version=`kubectl version --output=yaml|grep minor|head -n 1|tr -cd '[0-9]'`
    echo "k8s version: $(color_echo $green $k8s_version)"
}

download_images() {
    color_echo $yellow "auto download $k8s_version all k8s.gcr.io images..."
    pause_version=`cat /etc/containerd/config.toml|grep k8s.gcr.io/pause|grep -Po '\d\.\d'`
    k8s_images=(`kubeadm config images list 2>/dev/null|grep 'k8s.gcr.io'|xargs -r` "k8s.gcr.io/pause:$pause_version")
    for image in ${k8s_images[@]}
    do
        if [ $k8s_minor_version -ge 24 ];then
            if [[ `ctr -n k8s.io i ls -q|grep -w $image` ]];then
                echo " already download image: $(color_echo $green $image)"
                continue
            fi
        else
            if [[ `docker images $image|awk 'NR!=1'` ]];then
                echo " already download image: $(color_echo $green $image)"
                continue
            fi
        fi
        if [[ $can_google == 0 ]];then
            core_name=${image#*/}
            if [[ $core_name =~ "coredns" ]];then
                mirror_name="$mirror_source/coredns:`echo $core_name|egrep -o "[0-9.]+"`"
            else
                mirror_name="$mirror_source/$core_name"
            fi
            if [ $k8s_minor_version -ge 24 ];then
                ctr -n k8s.io i pull $mirror_name
                ctr -n k8s.io i tag $mirror_name $image
                ctr -n k8s.io i del $mirror_name
            else
                docker pull $mirror_name
                docker tag $mirror_name $image
                docker rmi $mirror_name
            fi
        else
            [ $k8s_minor_version -ge 24 ] && ctr -n k8s.io i pull $image || docker pull $image
        fi

        if [ $? -eq 0 ];then
            echo "Downloaded image: $(color_echo $blue $image)"
        else
            echo "Failed download image: $(color_echo $red $image)"
        fi
        echo ""
    done
}

run_k8s(){
    if [[ $is_master == 1 ]];then
        if [[ $network == "flannel" ]];then
            run_command "kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=`echo $k8s_version|sed "s/v//g"`"
            run_command "mkdir -p $HOME/.kube"
            run_command "cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
            run_command "chown $(id -u):$(id -g) $HOME/.kube/config"
            run_command "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
        elif [[ $network == "calico" ]];then
            run_command "kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=`echo $k8s_version|sed "s/v//g"`"
            run_command "mkdir -p $HOME/.kube"
            run_command "cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
            run_command "chown $(id -u):$(id -g) $HOME/.kube/config"
            run_command "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"
        fi
    else
        echo "this node is slave, please manual run 'kubeadm join' command. if forget join command, please run `color_echo $green "kubeadm token create --print-join-command"` in master node"
    fi
    if [[ `command -v crictl` ]];then
        crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
        [[ -z $(grep crictl ~/.bashrc) ]] && echo "source <(crictl completion bash)" >> ~/.bashrc
    fi
    color_echo $yellow "kubectl and kubeadm command completion must reopen ssh to affect!"
}

main() {
    check_sys
    prepare_work
    install_dependent
    install_k8s_base
    download_images
    run_k8s
}

main