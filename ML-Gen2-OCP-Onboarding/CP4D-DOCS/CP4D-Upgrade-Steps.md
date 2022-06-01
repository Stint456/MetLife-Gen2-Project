# CP4D-Upgrade-Steps:
## Not required for image pull registry as it is already there in cluster
```
oc extract secret/pull-secret -n openshift-config
export REGISTRY_USER=cp 
export REGISTRY_PASSWORD=entitlement-key 
export REGISTRY_SERVER=cp.icr.io
```

```
oc create secret docker-registry \
    --docker-server=${REGISTRY_SERVER} \
    --docker-username=${REGISTRY_USER} \
    --docker-password=${REGISTRY_PASSWORD} \
    --docker-email=${REGISTRY_USER} \
-n openshift-config pull-secret

echo -n "cp:entitlement-key" | base64 -w0

{
   "auths":{
       1 "registry-location":{
         "auth":"base64-encoded-credentials",
         "email":"not-used"
      },
       2 "myregistry.example.com":{
         "auth":"b3Blb=",
         "email":"not-used"
      }
   }
}

```

```
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=.dockerconfigjson

oc get nodes

--------------------------------------------------------------------------------------------------------------------------------------------------------

export CASE_REPO_PATH=https://github.com/IBM/cloud-pak/raw/master/repo/case
export OFFLINEDIR=$HOME/offline/cpd
export OFFLINEDIR_CPFS=$HOME/offline/cpfs
```



1.) Download the IBM Cloud Pak for Data platform operator CASE package
```
cloudctl case save \
--repo ${CASE_REPO_PATH} \
--case ibm-cp-datacore \
--version 2.0.11 \
--outputdir ${OFFLINEDIR} \
--no-dependency
```

2.) If IBM Cloud Pak foundational services is not installed on the cluster, download the IBM Cloud Pak foundational
```
cloudctl case save \
--repo ${CASE_REPO_PATH} \
--case ibm-cp-common-services \
--version 1.11.0 \
--outputdir ${OFFLINEDIR_CPFS}
```

3.) Download the CASE package for each service that you plan to install on your cluster:
```
cloudctl case save \
--repo ${CASE_REPO_PATH} \
--case ibm-datastage-enterprise \
--version 4.0.7 \
--outputdir ${OFFLINEDIR}
```

Run the following command to create the IBM Cloud Pak foundational services catalog source for the minimum supported version: If NOT AVAILABLE
```
cloudctl case launch \
  --case ${OFFLINEDIR_CPFS}/ibm-cp-common-services-1.11.0.tgz \
  --inventory ibmCommonServiceOperatorSetup \
  --namespace openshift-marketplace \
  --action install-catalog \
    --args "--registry ${PRIVATE_REGISTRY} --inputDir ${OFFLINEDIR_CPFS} --recursive"
```

4.) Verify that opencloud-operators is READY
```
oc get catalogsource -n openshift-marketplace opencloud-operators \
-o jsonpath='{.status.connectionState.lastObservedState} {"\n"}'

cloudctl case launch \
  --case ${OFFLINEDIR}/ibm-cp-datacore-2.0.11.tgz \
  --inventory cpdPlatformOperator \
  --namespace openshift-marketplace \
  --action install-catalog \
    --args "--inputDir ${OFFLINEDIR} --recursive"

oc get catalogsource -n openshift-marketplace cpd-platform \
-o jsonpath='{.status.connectionState.lastObservedState} {"\n"}'


cloudctl case launch \
  --case ${OFFLINEDIR}/ibm-datastage-enterprise-4.0.7.tgz \
  --inventory dsOperatorSetup \
  --namespace openshift-marketplace \
  --action install-catalog \
    --args "--inputDir ${OFFLINEDIR} --recursive"

oc get catalogsource -n openshift-marketplace ibm-cpd-datastage-operator-catalog \
-o jsonpath='{.status.connectionState.lastObservedState} {"\n"}'
```

5. )Creating operator subscription:
```

cat <<EOF |oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cpd-operator
  namespace: ibm-common-services   # Pick the project where you want to install the Cloud Pak for Data platform operator
spec:
  channel: v2.0
  installPlanApproval: Automatic
  name: cpd-platform-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF

oc get sub -n ibm-common-services cpd-operator -o jsonpath='{.status.installedCSV} {"\n"}'

cat <<EOF |oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata: 
  name: ibm-cpd-datastage-operator-subscription
  namespace: ibm-common-services    # Pick the project that contains the Cloud Pak for Data operator
spec: 
  channel: v1.0
  installPlanApproval: Automatic 
  name: ibm-cpd-datastage-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF

oc get sub -n ibm-common-services ibm-cpd-datastage-operator-subscription \
-o jsonpath='{.status.installedCSV} {"\n"}'
```

6.) CP4D Upgradation:

```

cat <<EOF |oc apply -f -
apiVersion: cpd.ibm.com/v1
kind: Ibmcpd
metadata:
  name: ibmcpd-cr                                     # This is the recommended name, but you can change it
  namespace: cp4d-automation1                             # Replace with the project where you will install Cloud Pak for Data
spec:
  license:
    accept: true
    license: Enterprise                   # Specify the Cloud Pak for Data license you purchased
  storageClass: ibmc-file-gold-gid                     # Replace with the RWX storage class used by your current installation
  zenCoreMetadbStorageClass: ibmc-file-gold-gid
EOF

cat <<EOF |oc delete -f -
apiVersion: cpd.ibm.com/v1
kind: Ibmcpd
metadata:
  name: ibmcpd-cr                                     # This is the recommended name, but you can change it
  namespace: cp4d-automation1                             # Replace with the project where you will install Cloud Pak for Data
spec:
  license:
    accept: true
    license: Enterprise                   # Specify the Cloud Pak for Data license you purchased
  storageClass: ibmc-file-gold-gid                     # Replace with the RWX storage class used by your current installation
  zenCoreMetadbStorageClass: ibmc-file-gold-gid
EOF

cloudctl case save \
--repo ${CASE_REPO_PATH} \
--case ibm-db2oltp \
--version 4.0.8 \
--outputdir ${OFFLINEDIR}

oc patch ZenService lite-cr \
--namespace <cpd-instance> \
--type=merge \
--patch '{"spec": {"version":"4.4.0"}}'


oc get zenservice -o json

cat <<EOF |oc apply -f -
apiVersion: ds.cpd.ibm.com/v1alpha1
kind: DataStage
metadata:
  name: datastage     # This is the recommended name, but you can change it
  namespace: cp4d-automation1     # Replace with the project where you will install DataStage
spec:
  license:
    accept: true
    license: Enterprise    # Specify the license you purchased
  version: 4.0.6
  storageClass: ibmc-file-gold-gid     # See the guidance in "Information you need to complete this task"
EOF
```


