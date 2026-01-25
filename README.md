# k3s-Cluster-Setup

A PowerShell tool for creating and managing local k3s Kubernetes clusters on Ubuntu Multipass VMs.

### Demo

[![screencast](https://raw.githubusercontent.com/firassBenNacib/k3s-Cluster-Setup/refs/heads/main/demo/demo.gif)](https://asciinema.org/a/772374)

## Table of Contents

* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Usage](#usage)
* [Commands](#commands)
* [Options](#options)
* [License](#license)
* [Author](#author)

## Prerequisites


* [Multipass](https://multipass.run/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)

## Installation

Clone:

```powershell
git clone https://github.com/firassBenNacib/k3s-Cluster-Setup.git
cd k3s-Cluster-Setup
````

## Usage

You can use the project in two ways:

* **Script:** `.\scripts\k3s-cluster-setup.ps1 <command> [args]`
* **Module:** import the module then run `Invoke-K3sClusterSetup <command> [args]`

### Quick start (script)

**1) Create a cluster (defaults: 1 server + 1 worker)**

```powershell
.\scripts\k3s-cluster-setup.ps1 create
```

**2) List clusters**

```powershell
.\scripts\k3s-cluster-setup.ps1 list
```

**3) Delete a cluster**

```powershell
.\scripts\k3s-cluster-setup.ps1 delete
```

### Quick start (module)

**1) Import the module**

```powershell
Import-Module .\src\k3s-cluster-setup\k3s-cluster-setup.psd1 -Force
```

**2) Create a cluster**

```powershell
Invoke-K3sClusterSetup create
```

**3) List clusters**

```powershell
Invoke-K3sClusterSetup list
```

**4) Delete a cluster**

```powershell
Invoke-K3sClusterSetup delete
```

### Interactive create

```powershell
.\scripts\k3s-cluster-setup.ps1 interactive
```

Or:

```powershell
Invoke-K3sClusterSetup interactive
```

### Use a merged kubeconfig (optional)

Script:

```powershell
.\scripts\k3s-cluster-setup.ps1 create mylab -MergeKubeconfig
.\scripts\k3s-cluster-setup.ps1 usecontext mylab
kubectl config current-context
```

Module:

```powershell
Invoke-K3sClusterSetup create mylab -MergeKubeconfig
Invoke-K3sClusterSetup usecontext mylab
kubectl config current-context
```

### Safety dry-run

Script:

```powershell
.\scripts\k3s-cluster-setup.ps1 delete mylab -WhatIf
```

Module:

```powershell
Invoke-K3sClusterSetup delete mylab -WhatIf
```

## Commands

```text
USAGE:
    k3s-cluster-setup <command> [cluster] [node] [options]

COMMANDS:
    create [cluster]                       Create a new k3s cluster
    interactive [cluster]                  Interactive create
    delete [cluster]                       Delete a cluster
    deletenode <cluster> [node]            Delete a specific node from a cluster
    stop [cluster]                         Stop a cluster
    start [cluster]                        Start a cluster
    list                                   List all k3s clusters
    listall                                List all Multipass VMs
    usecontext [context]                   Switch context in a merged kubeconfig
    help                                   Show help
```

## Options

**Common create options**

* `-Image <release/alias>`
* `-Channel <name>`
* `-ServerCount <n>` | `-AgentCount <n>`
* `-ServerCpu <n>` | `-AgentCpu <n>`
* `-ServerMemory <size>` | `-AgentMemory <size>`
* `-ServerDisk <size>` | `-AgentDisk <size>`
* `-DisableFlannel`
* `-Minimal` (disable Traefik, ServiceLB, metrics-server)
* `-OutputDir <path>`
* `-KeepCloudInit`
* `-NoKubeconfig`

**Advanced create options**

* `-K3sVersion <version>` (pin version)
* `-ServerToken <token>` | `-AgentToken <token>`
* `-DisableTraefik` | `-DisableServiceLB` | `-DisableMetricsServer`
* `-MergeKubeconfig`
* `-KubeconfigName <name/path>`
* `-MergedKubeconfigName <name/path>`
* `-LaunchTimeoutSeconds <n>`
* `-RemoteCmdTimeoutSeconds <n>`
* `-ApiReadyTimeoutSeconds <n>`
* `-NodeRegisterTimeoutSeconds <n>`
* `-NodeReadyTimeoutSeconds <n>`

**Delete options**

* `-All` (target all clusters for delete/stop/start)
* `-PurgeFiles`
* `-PurgeMultipass`
* `-Force`

**Safety / common parameters**

* `-WhatIf`
* `-Confirm`
* `-Verbose`

**Environment**

* `K3S_CLUSTER_SETUP_STATE`

## License

This project is licensed under the [MIT License](./LICENSE).

## Author

Created and maintained by Firas Ben Nacib - [bennacibfiras@gmail.com](mailto:bennacibfiras@gmail.com)
