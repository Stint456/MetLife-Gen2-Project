Direct sftp changes for gdi MFT Below are the Steps to be followed.



1) Creating secret for sftp passwords 
```
 NameSpace: mft-<env>

Outbound Password for GDI:
oc -n mft-ppd create secret generic ml-ou-gdi-pass --from-literal=password=<gdi user password> 
```

2) New Image Path to be Updated in all the Deployment Below.
```
NameSpace: mft-<env>

Image : us.icr.io/mft-<env>/mft-agent-gen2:1.2
destagent-rcv-mft-<env>-0
pbagent-rcv-mft-<env>-0
pbagent-send-mft-<env>-1
pbagent-send-mft-<env>-0
srcagent-send-mft-<env>-0
srcagent-send-mft-<env>-1
```
3) Outbound pba send yaml 0  need to be updated : 
```
NameSpace: mft-<env>
Deployment Name :pbagent-send-mft-ppd-0 		
-> Below Lines need to be updated under the env section of the yaml .
        - name: GDIUSER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ml-ou-gdi-pass
              key: password
        - name: GDIUSER_ID
          value: <GDI sftp user>
```
	 
4) Remove the gdi mount paths from srcagent-send-mft-ppd-0 
Below Mounts Need to be Deleted from Yaml.
```
NameSpace: mft-<env>

- name: mount-gen2-<env>-met-ext-gdi-out
              mountPath: /home/mftadmin/data/<ENV>/GDI/Output
              subPath: Output
```

5) download the new deployment(srcagent-send-mft-ppd-gdiuser-0) for gdiuser from box create the deployment.
```
NameSpace: mft-<env>

https://ibm.ent.box.com/folder/128883068125
```
6) register the new agent with the MQ Manager SRC_SEND_<ENV>_GDIUSER  in the MQMFT pod.
```
NameSpace:cp4i-<env>
	
/mnt/mqm/QMgrSetup/mqft_setupAgent.sh SRC_SEND_<ENV> _GDIUSER_0
```

7) Create the Resource Monitor in the New MFT agent created for GDI user.
```
/var/mqm/mft/bin/fteCreateMonitor -ix GDI_SEND_DATA.xml
```





