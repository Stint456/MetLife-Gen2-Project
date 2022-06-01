# Daily health check for PODS and Worker nodes #

Please ensure if Pod restart we have to provide the justification if application team ask.

Its mandatory to check managment pods which is running below mentioned namespaces

Instead of (int2)you have to change envirnoment name

>  1.cp4i-int2
> 
>  2.cp4d-int2
> 
>  3.portal-int2
> 
>  4.kube-system
> 
>  5.istio-system
> 
>  6.openshift

 To verify the pods status

 * oc get po -n (Namspace details)
 
 Describe the affected pods and look for the events 
 
 `oc describe pod cert-manager-controller-78f889db49-gnsgf -n ibm-common-services`
 
 ```
     State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Mon, 27 Sep 2021 07:07:20 +0000
      Finished:     Mon, 27 Sep 2021 07:07:50 +0000
    Ready:          False
    Restart Count:  272
```

We need to look for the Reason and Exit Code in the describe output.. Above example says OOMKilled & 137..It means what ever allocated memory doesnt enough for that application to process the request..Hence we need to increase the memory for the particular deployment/statefullset.

If the Reason and Exit Code is not meaningful or understandable, then we can check the logs of that particular pod and see any errors throwing and based on that we need to take an action.

```
oc logs po/pod-name -n namespace -c container-name

```

