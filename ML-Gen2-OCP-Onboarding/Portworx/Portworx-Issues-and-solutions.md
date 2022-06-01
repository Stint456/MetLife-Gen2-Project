## Portworx Issues and solutions: 

### Basic Portworx Troubleshooting

  + In any cluster for portworx we need to validate Portworx deamonset pods are running fine under *kube-system* namespace.
  ```
  sftptest@iipmgmtans01 ~]$ oc get pods -n kube-system |grep portworx
  I0921 10:24:11.647593   37440 request.go:621] Throttling request took 1.166834797s, request: GET:https://c116-e.us-south.containers.cloud.ibm.com:30374/apis/batch    /v1beta1?timeout=32s
  
  portworx-api-b9w72                              1/1     Running   0          77d
  
  portworx-api-bqv8d                              1/1     Running   0          285d
  portworx-api-g7spg                              1/1     Running   0          285d
  portworx-api-k48bw                              1/1     Running   0          33d
  portworx-api-ndzv4                              1/1     Running   0          285d
  portworx-api-p9jwj                              1/1     Running   0          285d
  portworx-api-qxd7v                              1/1     Running   0          285d
  portworx-api-wbsqz                              1/1     Running   0          285d
  portworx-api-xvjk4                              1/1     Running   0          285d
  portworx-f4nlb                                  1/1     Running   1          67d
  portworx-hrswx                                  1/1     Running   1          67d
  portworx-pvc-controller-b8c88b4d7-44wvs         1/1     Running   1          6d16h
portworx-pvc-controller-b8c88b4d7-kfq48         1/1     Running   0          6d7h
portworx-pvc-controller-b8c88b4d7-nlzmw         1/1     Running   0          6d14h
portworx-rf7h2                                  1/1     Running   0          67d
portworx-storageless-57548                      1/1     Running   1          33d
portworx-storageless-9jnnk                      1/1     Running   0          159d
portworx-storageless-9r9xl                      1/1     Running   1          159d
portworx-storageless-j5lqr                      1/1     Running   1          159d
portworx-storageless-kf7ml                      1/1     Running   0          159d
portworx-storageless-rdgks                      1/1     Running   1          159d
```

If any pod is failing for any reasons, try to get the node details where the pod is running and debug into that particular node and check for portworx service status and pxctl cluster status.

```
[sftptest@iipmgmtans01 ~]$ oc debug node/10.38.155.252
Starting pod/1038155252-debug ...
```
To use host binaries, run `chroot /host`
  Pod IP: 10.38.155.252

 If you don't see a command prompt, try pressing enter. 
 
 ```
 sh-4.4# chroot /host
sh-4.2# pxctl status
Status: PX is operational
License: PX-Enterprise IBM Cloud DR (expires in 925 days)
Node ID: 509ed30f-e17c-43e1-a28a-647f553e9819
        IP: 10.38.155.252
        Local Storage Pool: 1 pool
        POOL    IO_PRIORITY     RAID_LEVEL      USABLE  USED    STATUS  ZONE    REGION
        0       HIGH            raid0           3.5 TiB 31 GiB  Online  dal10   us-south
        Local Storage Devices: 1 device
        Device  Path            Media Type              Size            Last-Scan
        0:1     /dev/sdc1       STORAGE_MEDIUM_SSD      3.5 TiB         15 Sep 21 00:00 CDT
        total                   -                       3.5 TiB
        Cache Devices:
         * No cache devices
Cluster Summary
        Cluster ID: portworxstoragelayer
        Cluster UUID: 5f619690-8b66-4eca-930f-b4273a6e3cec
        Scheduler: kubernetes
        Nodes: 3 node(s) with storage (3 online), 6 node(s) without storage (6 online)
        IP              ID                                      SchedulerNodeName       StorageNode     Used    Capacity        Status  StorageStatus   Version              Kernel                          OS
        10.184.211.149  fa49566d-f3ad-473d-b7fb-6c0894619813    10.184.211.149          Yes             420 GiB 3.5 TiB         Online  Up              2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.38.155.252   509ed30f-e17c-43e1-a28a-647f553e9819    10.38.155.252           Yes             31 GiB  3.5 TiB         Online  Up (This node)  2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.36.105.86    4da33d97-ad99-46d2-bd41-bd557cc03702    10.36.105.86            Yes             430 GiB 3.5 TiB         Online  Up              2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.36.105.85    f7d0404a-61f8-410a-be50-8af834b233be    10.36.105.85            No              0 B     0 B             Online  No Storage      2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.184.211.140  c2e38fd8-d09b-4598-afbd-98d48803d962    10.184.211.140          No              0 B     0 B             Online  No Storage      2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.38.155.197   9c04fb24-519c-4162-8c18-1ebebfd63310    10.38.155.197           No              0 B     0 B             Online  No Storage      2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.36.105.72    93b369bf-925b-4a3e-9cd1-ff9bc2f23db8    10.36.105.72            No              0 B     0 B             Online  No Storage      2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.38.155.211   7ba999cb-552e-4779-baea-59b818dbe098    10.38.155.211           No              0 B     0 B             Online  No Storage      2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
        10.184.211.135  5b74132e-47a5-4c3f-a901-39acc1301bb1    10.184.211.135          No              0 B     0 B             Online  No Storage      2.6.2.1-4c79af9      3.10.0-1160.42.2.el7.x86_64     Red Hat
Global Storage Pool
        Total Used      :  881 GiB
        Total Capacity  :  10 TiB
```
Check the systemctl service as below:

```
sh-4.2# systemctl status portworx
● portworx.service - Portworx OCI Container
   Loaded: loaded (/etc/systemd/system/portworx.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2021-09-15 00:00:14 CDT; 6 days ago
     Docs: https://docs.portworx.com/runc
  Process: 25931 ExecStartPre=/bin/sh -c /opt/pwx/bin/runc delete -f portworx || true (code=exited, status=0/SUCCESS)
Main PID: 25943 (runc)
    Tasks: 477
   Memory: 12.3G
   CGroup: /system.slice/portworx.service
           ├─25943 /opt/pwx/bin/runc run -b /opt/pwx/oci --no-new-keyring portworx
           └─portworx
             ├─  25988 /usr/bin/python /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
             ├─  28905 /usr/bin/lttng-relayd -o /var/lib/osd/log/px_trace
             ├─  28906 /usr/sbin/cron -f -L 4
             ├─  28909 /bin/bash -x /usr/local/bin/lttng.sh --tracefile-diskusage 0 --sub-buf-sz 1024 --sub-buf-num 2 --lttng-running /tmp/lttng_running
             ├─  28911 /usr/local/bin/pxexec
             ├─  28912 python3 /usr/local/bin/px_cache_mon.py --start
             ├─  28918 /usr/local/bin/px-diag
             ├─  28922 /usr/local/bin/px-healthmon
             ├─  28924 /usr/bin/python2.7 /usr/local/bin/start_pxcontroller_pxstorage.py
             ├─  28925 /usr/local/bin/px-ns
             ├─  28931 /usr/bin/python /usr/local/bin/supervisord_event_handler.py
             ├─  29359 /usr/local/bin/px-storage
             ├─  29618 /usr/local/bin/px -daemon
             ├─  29619 /bin/bash /usr/local/bin/watchdog.sh
             ├─1311130 sleep 120
             └─1322272 sleep 63
 
Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.
```
If the portworx status is having any issue, try to restart the portworx service by running following command.

```
systemctl restart portworx
```
Even after restart if the pods are failing , then we need to raise a case with portworx in:

[https://pure1.purestorage.com](https://pure1.purestorage.com)

---
### Issues Faced:
#### Issue 1.- portworx pods status showing 0/1 and it keeps restart in DR cluster
  
  **Summary**: The portworx deamonset pods were keep on restarting and showing status as 0/1 in DR cluster and error log says:  

  ```
  Could not init scheduler 'kubernetes': Could not find my node in Kubernetes cluster: Get https://172.21.0.1:443/api/v1/nodes: dial tcp 172.21.0.1:443: connect:   connection timed out
  ``` 

  #### **Solution:** 
  After having a brief call with Product team we identified that DR cluster had wrong UUID and cluster name in the Portworx configuration yaml. So we need to login into each node and modify the cluster name and restart the portworx service to pickup up the new name 
  
  + Steps: 
  
    + 1.- Login into affected portworx node and edit the config file which is located on “/etc/pwx/config.json”  

    + 2.- Update the “clusterid” value to appropriate cluster name:
    ```
    sh-4.2# cat config.json
    {
      "alertingurl": "",
      "clusterid": "gen2-pdr",
      "dataiface": "",
      "kvdb": [
        "etcd:https://e68dcf4c-dbdd-4bb0-aac5-89516caf907a.bkvfvtld0lmh0umkfi70.private.databases.appdomain.cloud:31216"
     ],
     "mgtiface": "",
     "scheduler": "kubernetes",
     "cafile": "/etc/pwx/etcdcerts/ca.pem",
     "username": "ibm_cloud_e5f2de86_3bb0_4abf_acb6_c14858fe5867",
     "password": "75bad1f445e8deb6758ef282a3f2d65b54c3cd9344e5618ac8cc80de85b40772",
     "secret": {
       "secret_type": "ibm-kp",
       "cluster_secret_key": ""
      },
      "storage": {
        "devices": [
          "/dev/sdc1"
        ],
        "cache": [],
        "rt_opts": {},
        "max_storage_nodes_per_zone": 0,
        "journal_dev": "",
        "system_metadata_dev": "",
        "kvdb_dev": ""
      },
      "version": "1.0"
    }
    ```
    + 3.- Restart the portworx service in the node using the following command
    
    ``` 
    systemctl restart portworx 
    ```

    + 4.- Validate Portworx Pod is up and running in the node.

#### Issue 2.- Portworx pods are down in some nodes
+ Error in pod:  
```
$oc logs -n kube-system portworx-pvc-controller-88f85f974-kbbxp)
E0917 07:35:54.972531       1 reflector.go:127] k8s.io/apiserver/pkg/authentication/request/headerrequest/requestheader_controller.go:172: Failed to watch
*v1.ConfigMap: failed to list *v1.ConfigMap: configmaps "extension-apiserver-authentication" is forbidden: User "system:serviceaccount:kube-system:portworx-pvc-
controller-account" cannot list resource "configmaps" in API group "" in the namespace "kube-system"E0917 07:36:22.917676       1 reflector.go:127] k8s.io/apiserver
/pkg/server/dynamiccertificates/configmap_cafile_content.go:206: Failed to watch *v1.ConfigMap: failed to list *v1.ConfigMap: configmaps "extension-apiserver-
authentication" is forbidden: User "system:serviceaccount:kube-system:portworx-pvc-controller-account" cannot list resource "configmaps" in API group "" in the 
namespace "kube-system"E0917 07:36:23.196243       1 reflector.go:127] k8s.io/apiserver/pkg/server/dynamiccertificates/configmap_cafile_content.go:206: Failed to 
watch *v1.ConfigMap: failed to list *v1.ConfigMap: configmaps "extension-apiserver-authentication" is forbidden: User "system:serviceaccount:kube-system:portworx-
pvc-controller-account" cannot list resource "configmaps" in API group "" in the namespace "kube-system"E0917 07:36:48.801630       1 reflector.go:127] 
k8s.io/apiserver/pkg/authentication/request/headerrequest/requestheader_controller.go:172: Failed to watch *v1.ConfigMap: failed to list *v1.ConfigMap: configmaps
"extension- apiserver-authentication" is forbidden: User "system:serviceaccount:kube-system:portworx-pvc-controller-account" cannot list resource "configmaps" in
API group "" in the namespace "kube-system"
```
  #### **Solution:** 
+ Validate in which node the portworx pods are down.
+ Validate the Portworx services are running in the specific node. 
  + In order to complete that, debug into the worker node and run: 
    ``` 
    systemctl status portworx
    ``` 
+ Validate whether any infra component pods are running in the specific node which has any error.
+ Try to move the vpn pods to alternate node from current running node by cordoning the node.
+ Validate the node health status (CPU, Memory, Disk utilization).
+ Restart the problematic node.

Also sometimes during this kind of issues, Portworx might try to reinstall the setup in the specific nodes.
During reinstall it will get the new id for that node and get added as a new node in the portworx cluster and existing entry of same node might not get removed 
automatically.

This will not cause any functionality issue but still we need to remove the old node entry from the list using following command.

```
pxctl delete cluster cluster-id 
```   

(Get the id details from pxctl status command for the node which we need to remove and replace that id details in cluster-id section in the command.)

![image](https://github.ibm.com/MetLife-Gen2/ML-Gen2-OCP-Onboarding/blob/bernardo-segura/Portworx/images/pxclt_statuspng.png)
