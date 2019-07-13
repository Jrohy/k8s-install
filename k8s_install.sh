#!/bin/bash
# Author: Jrohy
# Github: https://github.com/Jrohy/k8s-install

# cancel centos alias
[[ -f /etc/redhat-release ]] && unalias -a

#######color code########
RED="31m"      
GREEN="32m"  
YELLOW="33m" 
BLUE="36m"
FUCHSIA="35m"

GOOGLE_URLS=(
    packages.cloud.google.com
    k8s.gcr.io
)

CAN_GOOGLE=1

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

ipIsConnect(){
    ping -c2 -i0.3 -W1 $1 &>/dev/null
    if [ $? -eq 0 ];then
        return 0
    else
        return 1
    fi
}

checkSys() {
    #检查是否为Root
    [ $(id -u) != "0" ] && { colorEcho ${RED} "Error: You must be root to run this script"; exit 1; }

    #检查系统信息
    if [[ -e /etc/redhat-release ]];then
        if [[ $(cat /etc/redhat-release | grep Fedora) ]];then
            OS='Fedora'
            PACKAGE_MANAGER='dnf'
        else
            OS='CentOS'
            PACKAGE_MANAGER='yum'
        fi
    elif [[ $(cat /etc/issue | grep Debian) ]];then
        OS='Debian'
        PACKAGE_MANAGER='apt-get'
    elif [[ $(cat /etc/issue | grep Ubuntu) ]];then
        OS='Ubuntu'
        PACKAGE_MANAGER='apt-get'
    elif [[ $(cat /etc/issue | grep Raspbian) ]];then
        OS='Raspbian'
        PACKAGE_MANAGER='apt-get'
    else
        colorEcho ${RED} "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi

    for ((i=0;i<${#GOOGLE_URLS[*]};i++))
    do
        ipIsConnect ${GOOGLE_URLS[$i]}
        if [[ ! $? -eq 0 ]]; then
            colorEcho ${YELLOW} " 当前服务器无法访问谷歌, 切换为国内的镜像源.."
            CAN_GOOGLE=0
            break	
        fi
    done

}

#安装依赖
installDependent(){
    if [[ ${OS} == 'CentOS' || ${OS} == 'Fedora' ]];then
        ${PACKAGE_MANAGER} install bash-completion -y
    else
        ${PACKAGE_MANAGER} update
        ${PACKAGE_MANAGER} install bash-completion apt-transport-https gpg -y
    fi
}

prepareWork() {
    ## 安装最新版docker
    if [[ ! $(type docker 2>/dev/null) ]];then
        colorEcho ${YELLOW} "本机docker未安装, 正在自动安装最新版..."
        source <(curl -sL https://git.io/fj8OJ)
    fi
    ## 关闭防火墙
    systemctl disable firewalld.service
    systemctl stop firewalld.service
    ## 禁用SELinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
    ## 关闭swap
    swapoff -a
    sed -i 's/.*swap.*/#&/' /etc/fstab
}

installK8sBase() {
    if [[ $CAN_GOOGLE == 1 ]];then
        if [[ $OS == 'Fedora' || $OS == 'CentOS' ]];then
            cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
            yum install -y kubelet kubeadm kubectl
        else
            curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
            echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
            apt-get update
            apt-get install -y kubelet kubeadm kubectl
        fi
    else
        if [[ $OS == 'Fedora' || $OS == 'CentOS' ]];then
            cat>>/etc/yum.repos.d/kubrenetes.repo<<EOF
[kubernetes]
name=Kubernetes Repo
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
EOF
            yum install -y kubelet kubeadm kubectl
        else
            cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
EOF
            gpg --keyserver keyserver.ubuntu.com --recv-keys BA07F4FB
            gpg --export --armor BA07F4FB | apt-key add -
            apt-get update
            apt-get install -y kubelet kubeadm kubectl
        fi
    fi
    systemctl enable kubelet && systemctl start kubelet

    #命令行补全
    echo "source <(kubectl completion bash)" >> ~/.bashrc
    echo "source <(kubeadm completion bash)" >> ~/.bashrc
    source ~/.bashrc
}

main() {
    checkSys
    prepareWork
    installDependent
    installK8sBase
}

main