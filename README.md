# Add Windows Workers to an existing cluster


**Table of Contents**
- [Features](#Features)
- [Introduction](#Introduction)
- [Prepare Kubernetes master](#Prepare-Kubernetes-master)
- [Installation](#Installation)
  - [Pre-requisite](#Pre-requisite)
  - [Configuration options](#Configuration-options)
  - [Docker](#Docker)
  - [Base Image](#Base-Image)
  - [Setup](#Setup)
  - [Logs](#Logs)
- [Reset](#reset)
- [Troubleshooting](#troubleshooting)

# Features
Add windows worker node to an existing cluster
## Networking driver support
- [x] Flannel
  - [x] overlay

# Introduction
To run windows containers, we require a multi-operating system cluster with a Control plan running on Linux and workers running on Windows or Linux depending on workloads.
- Windows Server 2019(only supported OS version)
- Windows host does not support privileged containers.
- Windows container base image version must be compatible with the host OS kernel version.
- Networking

## Flannel Overlay

Flannel in vxlan mode can be used to set up a configurable virtual overlay network that uses VXLAN tunneling to route packets between nodes.

## Prepare Kubernetes master
Some minor preparation is needed on the Kubernetes master. It is recommended to enable bridged IPv4 traffic to iptables chains when using flannel.
```
sudo sysctl net.bridge.bridge-nf-call-iptables=1
```
There are two sections you should modify to enable the vxlan networking backend:
1. In the net-conf.json section of your kube-flannel.yml, double-check:
 - The cluster subnet (e.g. "10.244.0.0/16") is set as desired.
 - VNI 4096 is set in the backend
 - Port 4789 is set in the backend
2. In the cni-conf.json section of your kube-flannel.yml, change the network name to "vxlan0".

After applying the above steps, the net-conf.json should look as follows:
```
   net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan",
        "VNI" : 4096,
        "Port": 4789
      }
    }
```
 
  The cni-conf.json should look as follows:
```
   cni-conf.json: |
    {
      "name": "vxlan0",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
```
  Since flannel pods are Linux-based, apply nodeSelector to flannel DaemonSet to only target Linux Nodes. Flannel will run as host service on windows nodes.
  

# Installation
*Make sure the Master node is configured as suggested in [Master Setup](#Prepare-Kubernetes-master)*
**The VNI must be set to 4096 and port 4789 for Flannel on Linux to interoperate with Flannel on Windows.**


## Pre-requisite
**Create the installation directory(`mkdir c:\k`) and pass the path as command line argument(`$BaseDir`).**

**Download/Copy the kubeconfig inside the above directory as `kubeconfig`.**

## Configuration options
Windows node can be configured using available command line arguments.
```
| Command-line argument | Description | Default |
|-----------------------|--------------------------------------------------------------------------------------------|---------------|
| BaseDir | Directory path for setup(needs to be created before) | c:\k |
| ClusterCIDR | CIDR block to be used for clusterIPs | 10.244.0.0/16 |
| ServiceCIDR | CIDR block to be used for serviceIPs | 10.10.0.0/16 |
| InterfaceName | Host network interface to be used | Ethernet0 |
| Release | Kubernetes release version | 1.21.5 |
| Reset | Resets configuration by removing created networks & services(flanneld, kubelet, kubeproxy) | false |
```

## Docker
Docker must be already installed on the windows host. If not, follow the steps provided on [Docker-Windows-Server-Install](https://docs.docker.com/install/windows/docker-ee/).

## Base Image
Containers are essentially namespacing host processes. Windows containers are tightly coupled with the host kernel version, so they need to be compatible.

Get host OS kernel version using: 
```
`systeminfo | findstr /B /C:"OS Name" /C:"OS Version"`
```
There are 2 version of base windows containers:
- nanoserver: lightweight version
- servercore: feature rich non-ui version of windows server

Refer to the compatibility matrix for [nanoserver](https://hub.docker.com/_/microsoft-windows-nanoserver) and [servercore](https://hub.docker.com/_/microsoft-windows-servercore) to determine the image tag version that is supported based on Os version.

The image compatibility can be verified by running the docker image with the correct image tag.
```
`docker container run mcr.microsoft.com/windows/nanoserver:<tag>`
```
## Setup
Run the Powershell script `setup_windowsnode.ps1` with the command-line options as discussed in the configuration.

Flow:
- Check docker is running
- Download the windows docker base images(nanoserver & servercore) and verify compatibility with the host by running them. Tag the images as `latest`.
- Build kubernetes pod pause image based on the nanoserver base image. Pause image is used by kubernetes pods to attach the networking stack.
- Install Kubernetes binaries (kubectl, kubelet, kubepoxy, kubeadm) for the specified release.
- Download and Install Networking binaries(cni, flannel). Update the CNI configuration and net configuration for the cni networking setup.
- Install & Start kubelet as a server. This will registed the windows node.
- Create an external overlay network to trigger a vSwitch creation(done only once) and add a firewall rule to allow UDP traffic at port 4789 for flannel overlay networking.
- Start flannel and wait for it to create an overlay network.
- Install & Start KubeProxy as a service

## Logs
- flanneld: `$BaseDir\logs\flanneld`
- kubelet: `$BaseDir\logs\kubelet`
- kubeproxy: `$BaseDir\logs\kubeproxy`

# Reset
Run `setup_windowsnode.ps1 -Reset true` to clean up the overlay network and remove services(flanneld, kubelet, kubeproxy)

# Troubleshooting
- To verify kubelet is running use `get-process kubelet`
- To check kube-proxy is running use `get-process kubeproxy`
- To check flannel is running use `get-process flannel`
- If services are not running, verify the [logs](#Logs)
