 [Reference link to deploy LogDNA on openshist cluster](https://cloud.ibm.com/docs/openshift?topic=openshift-health-audit
 )
- [Kubernetes API server audit logs](#kubernetes-api-server-audit-logs)
- [Forwarding Kubernetes API audit logs to LogDNA](#forwarding-kubernetes-api-audit-logs-to-logdna)
- [To forward Kubernetes API audit logs to IBM Log Analysis with LogDNA](#to-forward-kubernetes-api-audit-logs-to-ibm-log-analysis-with-logdna)

# Kubernetes API server audit logs 
To monitor user-initiated, Kubernetes administrative activity made within your cluster, you can collect and forward audit events that are passed through your Kubernetes API server to IBM Log Analysis with LogDNA or an external server. Although the Kubernetes API server for your cluster is enabled for auditing by default, no auditing data is available until you set up log forwarding.

# Forwarding Kubernetes API audit logs to LogDNA #
To set up your cluster to forward audit logs to IBM Log Analysis with LogDNA, you can create a Kubernetes audit system by using the provided image and deployment.

The Kubernetes audit system in your cluster consists of an audit webhook, a log collection service and webserver app, and a logging agent. The webhook collects the Kubernetes API server events from your cluster master. The log collection service is a Kubernetes ClusterIP service that is created from an image from the public IBM Cloud registry. This service exposes a simple node.js HTTP webserver app that is exposed only on the private network. The webserver app parses the log data from the audit webhook and creates each log as a unique JSON line. Finally, the logging agent forwards the logs from the webserver app to IBM Log Analysis with LogDNA, where you can view the logs.

## To forward Kubernetes API audit logs to IBM Log Analysis with LogDNA ##

  * Target the global container registry for public IBM Cloud images.

 >       $ ibmcloud cr region-set global

Output:
The region is set to 'global', the registry is 'icr.io'.

OK


 *  Optional: For more information about the kube-audit image, inspect icr.io/ibm/ibmcloud-kube-audit-to-logdna

 >      $ ibmcloud cr image-inspect icr.io/ibm/ibmcloud-kube-audit-to-logdna

* Create a configuration file that is named ibmcloud-kube-audit.yaml. This configuration file creates a log collection service and a deployment that pulls the icr.io/ibm/ibmcloud-kube-audit-to-logdna image to create a log collection container.

```
apiVersion: v1
kind: List
metadata:
 name: ibmcloud-kube-audit
items:
 - apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: ibmcloud-kube-audit
     labels:
       app: ibmcloud-kube-audit
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: ibmcloud-kube-audit
     template:
       metadata:
         labels:
           app: ibmcloud-kube-audit
       spec:
         containers:
           - name: ibmcloud-kube-audit
             image: 'icr.io/ibm/ibmcloud-kube-audit-to-logdna:latest'
             ports:
               - containerPort: 3000
 - apiVersion: v1
   kind: Service
   metadata:
     name: ibmcloud-kube-audit-service
     labels:
       app: ibmcloud-kube-audit
   spec:
     selector:
       app: ibmcloud-kube-audit
     ports:
       - protocol: TCP
         port: 80
         targetPort: 3000
     type: ClusterIP
```


* Create the deployment in the default namespace of your cluster.
>      $ kubectl create -f ibmcloud-kube-audit.yaml

```
Output:
The region is set to 'global', the registry is 'icr.io'.

OK
````


* Verify that the ibmcloud-kube-audit-service pod has a STATUS of Running.

>      $ kubectl get pods -l app=ibmcloud-kube-audit

```
Output:
NAME                                             READY   STATUS             RESTARTS   AGE
ibmcloud-kube-audit-c75cb84c5-qtzqd              1/1     Running   0          21s
```

* Verify that the ibmcloud-kube-audit-service service is deployed in your cluster. In the output, note the CLUSTER_IP.
   
>      $ kubectl get svc -l app=ibmcloud-kube-audit

```
Output:

NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
ibmcloud-kube-audit-service   ClusterIP   172.21.183.68   <none>        80/TCP           1m

```
* Create the audit webhook to collect Kubernetes API server event logs. Add the http:// prefix to the CLUSTER_IP.

>     $ ibmcloud oc cluster master audit-webhook set --cluster gen2-int2 --remote-server http://172.21.183.68

```
Output:
Kubernetes removed deprecated APIs, which impacts clusters that run Kubernetes version 1.16, OpenShift version 4.4, or later. For more information, see <http://ibm.biz/k8s-1-16-apis>

The Kubernetes Ingress controller image is now supported for Ingress ALBs, and all new ALBs now run the Kubernetes Ingress image by default. Additionally, you must move any existing Ingress setups to the new Kubernetes Ingress before support for the legacy IBM Cloud Kubernetes Service Ingress image ends on April 30, 2021. More info: <https://ibm.biz/kube-ingress>

From 01 December 2020 virtual and bare metal servers that run Ubuntu 16 will be deprecated, in consideration of the upcoming April 2021 end-of-support date for Ubuntu 16. For more details, please see the announcement <https://ibm.biz/kube-flavors>

From 01 December 2020 the older generation bare metal flavors will be deprecated. For more details, please see the announcement <https://ibm.biz/kube-flavors>

If you have IBM Cloud Kubernetes Service clusters that run version 1.15 or 1.16, update them now to continue receiving important security updates and support. Version 1.16 is deprecated and will be unsupported 30 January 2021. Versions 1.15 and earlier are already unsupported. For more information and update actions, see <https://ibm.biz/iks-versions>

If you have Red Hat OpenShift on IBM Cloud clusters that run version 4.3, update them now to continue receiving important security updates and support. Version 4.3 is deprecated and will be unsupported 7 March 2021. For more information and update actions, see <https://cloud.ibm.com/docs/openshift?topic=openshift-openshift_versions>

Setting Kubernetes API server audit webhook config for gen2-int2...
OK
```


* Verify that the audit webhook is created in your cluster.
  
>     $ ibmcloud oc cluster master audit-webhook get --cluster gen2-int2

```
Output:
Getting Kubernetes API server audit webhook config for gen2-int2...
OK

```

* Apply the webhook to your Kubernetes API server by refreshing the cluster master. It might take several minutes for the master to refresh.

>      $ ibmcloud oc cluster master refresh --cluster gen2-int2

```
Output:
Refreshing API server(s) for cluster gen2-int2...
OK
```
