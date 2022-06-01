Direct sftp changes for MFT Below are the Steps to be followed .

1.TWS Script Need to be Updated.
```
https://ibm.ent.box.com/file/840085442335
Script in this Box Link need to be Placed in  this path : /home/wauser/GEN2-Data/TWS_Scripts/
NameSpace: wa-agent-<env>

Below Pods for Prd only :
wa-agent-prd-waagent-0
wa-agent-prd2-waagent-0
```


2.Creating secret for sftp passwords
``` 
NameSpace: mft-<env>

Inbound Password:
oc -n mft-ppd create secret generic ml-in-pass --from-literal=password=<inbound user password>

Outbound Password:
oc -n mft-ppd create secret generic ml-ou-pass --from-literal=password=<outbound user password>

Outbound Password for RDZ:
oc -n mft-ppd create secret generic ml-ou-rdz-pass --from-literal=password=<rdz user password>
```

3.New Image Path to be Updated in all the Deployment Below.
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
4. Outbound pba send yaml 0  need to be updated :
``` 
NameSpace: mft-<env>
Deployment Name :pbagent-send-mft-ppd-0 		
-> Below Lines need to be updated under the env section of the yaml .
        - name: TGT_SERVER_HOST_NAME
          value: 10.218.111.167
        - name: SFTP_PORT
          value: '20901'
        - name: TGT_SERVER_PASSWD
          valueFrom:
            secretKeyRef:
              name: ml-ou-pass
              key: password
        - name: TGT_SERVER_ID
          value: <Generic Outbound SFTP user>
        - name: RDZUSER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ml-ou-rdz-pass
              key: password
        - name: RDZUSER_ID
          value: <RDZ sftp user>
```	 


5. Outbound pba send yaml 1 need to be updated :
``` 
NameSpace: mft-<env>

Deployment Name :pbagent-send-mft-ppd-1
        - name: TGT_SERVER_HOST_NAME
          value: 10.218.111.167
        - name: SFTP_PORT
          value: '20901'
        - name: TGT_SERVER_PASSWD
          valueFrom:
            secretKeyRef:
              name: ml-ou-pass
              key: password
        - name: TGT_SERVER_ID
          value: <Generic Outbound SFTP user>
```
6. For Inbound  pbagent-rcv-mft-<env>-0 below need to be updated under env session of the yaml.
```
NameSpace: mft-<env>


        - name: TGT_SERVER_HOST_NAME
          value: 10.218.111.167
        - name: SFTP_PORT
          value: '20901'
        - name: TGT_SERVER_PASSWD
          valueFrom:
            secretKeyRef:
              name: ml-in-pass
              key: password
        - name: TGT_SERVER_ID
          value: <Generic Inbound SFTP user>

```



7. Remove the rdz mount paths from srcagent-send-mft-ppd-0 
Below Mounts Need to be Deleted from Yaml .
```
NameSpace: mft-<env>

            - name: mount-gen2-<env>-met-ext-rdz-out
              mountPath: /home/mftadmin/data/<ENV>/RDZ/Output
              subPath: Output
            - name: mount-gen2-<env>-met-ext-rdz-out
              mountPath: /home/mftadmin/data/<ENV>/RDZ/Data
              subPath: Data
            - name: mount-gen2-<env>-met-ext-rdz-out
              mountPath: /home/mftadmin/data/<ENV>/RDZ/Trigger
              subPath: Trigger

```
Delete the Resource Monitors from srcagent-send-mft-ppd-0
```

/var/mqm/mft/bin/fteDeleteMonitor -ma SRC_SEND_<ENV>_0 -mn RDZ_SEND_DATA
/var/mqm/mft/bin/fteDeleteMonitor -ma SRC_SEND_<ENV>_0 -mn RDZ_SEND_TRIGGER
/var/mqm/mft/bin/fteDeleteMonitor -ma SRC_SEND_<ENV>_0 -mn RDZ_SEND_CONTROL
```

8. Download the new deployment(srcagent-send-mft-ppd-rdzuser-0) for rdzuser from box create the deployment.
```
NameSpace: mft-<env>

https://ibm.ent.box.com/file/891822028448
```

9. Register the new agent with the MQ Manager SRC_SEND_<ENV>_RDZUSER  in the MQMFT pod.
```
NameSpace:cp4i-<env>
/mnt/mqm/QMgrSetup/mqft_setupAgent.sh SRC_SEND_<ENV> _RDZUSER_0
```
10. Delete the RDZ resource monitors from Box and copy the xml files into srcagent-send-mft-<env>-rdzuser-0  pod and create the RDZ resource monitors in srcagent-send-mft-<env>-rdzuser-0

Download Below Resource Monitors from Box Link and created them accordingly.
```
https://ibm.ent.box.com/folder/151453374338

/var/mqm/mft/bin/fteCreateMonitor -ix RDZ_SEND_DATA.xml
/var/mqm/mft/bin/fteCreateMonitor -ix RDZ_SEND_TRIGGER.xml
/var/mqm/mft/bin/fteCreateMonitor -ix RDZ_SEND_CONTROL.xml
```


