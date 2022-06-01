#!/bin/bash

#################################################################################################
# 			Portworx Installation Script						#
#			============================						#
#											     	#
# 	This script is used to install Portworx on OpenShift Cluster. 				#
#	It can be used to install either on single zone cluster or a multi-zone cluster.	#
#												#
#	Maintained By: Shrinivas Bolli (shriboll@in.ibm.com)					#
#	Copyright (C) 2020, IBM									#
#												#
#	Change History										#
#	09/28/2020	Shrinivas Bolli			Initial version				#
#	09/28/2020	Shrinivas Bolli			Added tags to service instances		#
#												#
#################################################################################################

echo "$(date "+%Y%m%d%H%M%S"): Starting installation of Portworx ###############"
#set -e
source portworx.properties

# Initializing global variables
username=""
password=""
node_ip=""
datacenter=""
order_id=""
vol_id=""
target_ip=""
host_iqn=""
lunid=""
resource_id=""
kp_instance_id=""
root_key_id=""
uname=""
passwd=""
certificate=""
etcd_endpoints=""
api_key=""

# This function will exit the script and prints error message and exit code of last command
exit_on_error() {
	exit_code=$1
    	last_command=${@:2}
    	if [ $exit_code -ne 0 ]; 
	then
        	>&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
	  	exit $exit_code
	fi
}

# Enable !! command completion
set -o history -o histexpand

if [[ -z $no_of_zones ]]
then
	echo "Please enter a value for no_of_zones variable in portworx.properties file. Exiting the script..."
	exit 1
fi
echo "No. of zones = "$no_of_zones

#Check if resource group already exists
check_resource_group(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Checking whether resource group "${resource_group}" exists or not..."
	output=$(ibmcloud resource group $resource_group 2>&1)
	echo "$output"
	if [[ $output == *"FAILED"* ]]
	then
		echo "Resource group does not exists. Please check the resource group name in properties file. Exiting..."
		exit 1
	else
		echo "Resource group already exists..."
		resource_id=($(echo "$output" | grep ID | awk 'NR==2 {print $2}'))
		echo "Resource id = "$resource_id
	fi
}

#Check if already logged in to ocp cluster
login_check() {
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Checking whether already logged into cluster..."
	oc projects > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		echo "Already logged into cluster. Logging out..."
		oc logout
	fi
	echo "Login to cluster "$ocp_server
	oc login -u apikey -p $ocp_apikey --server=${ocp_server}
	exit_on_error $?
}

# Create array of node ip's
create_node_ip_arr(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating array of node ip's ..."
	ip_arr=($(oc get nodes -o wide | awk 'NR>1 {print $6}'))
	exit_on_error $?

	echo "Printing node ip's ..."
	for i in "${ip_arr[@]}"
	do
        	echo $i
	done
}

# Checking if node with IP's given in properties file exists on the cluster 
validate_node_ips(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Validating node ips..."
	for (( i=1; i<=3; i++ ))
	do
		node_ip="node_ip_"$i
		if [[ "${ip_arr[*]}" == *"${!node_ip}"* ]]
		then
        		echo "Node with ip "${!node_ip}" exists"
		else
        		echo "Node with IP "${!node_ip}" DOES NOT EXISTS on the cluster. Please provide correct node ip's in the properties file. Exiting the script..."
			exit 1
		fi
	done
}

initial_prep_work(){
	echo "###################################################################"
	# IBM Cloud login
	echo "$(date "+%Y%m%d%H%M%S"):Login to ibm cloud..."
	ibmcloud login -apikey $ocp_apikey
	exit_on_error $?

	# Check for resource group
	check_resource_group

	# Add iks/charts helm repo
	echo "Adding iks-charts repo to local helm repos and updating the repos..."
	helm repo add iks-charts https://icr.io/helm/iks-charts
	exit_on_error $?

	# Update helm repos
	helm repo update
	helm repo list
}

# Check if attacher plugin is installed on all nodes. If not install it
check_attacher_plugin(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Checking for attacher plugin..."
	oc project kube-system
	oc get pods -n kube-system | grep "attacher" > /dev/null 2>&1
	if [ $? -eq 0 ] 
	then
		echo "Attacher plugin already installed"
	else
		echo "Attacher plugin not installed. Installing the plugin..."
		helm install block-attacher iks-charts/ibm-block-storage-attacher
		exit_on_error $?
		wait
	fi
	# Verify that IBM Cloud Block Attacher deamon set is installed successfully
	oc get pods -n kube-system | grep "attacher" 
       if [ ! $? -eq 0 ]
       then
	       echo "Block attacher plugin installation failed. Exiting..."
	       exit 1
       fi
}

# Place volume order
order_volume() {
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"): Placing volume order..."
	datacenter=$1
	node_ip=$2
	echo "Datacenter : "$datacenter
	echo "node_ip : "$node_ip
	#output=`cat output.txt`
	output=$(ibmcloud sl block volume-order --storage-type endurance --size ${size} --tier ${tier} --os-type LINUX --datacenter ${datacenter} -f 2>&1)
	exit_on_error $?

	#echo "$output"
	if [[ $output == *"Failed"* ]]
	then
		echo "Order request failed with error message - "
		echo "$output"
		exit 1
	fi		
	# Retrieve order_id from command output
	order_id=($(sed 's/[^0-9]*//' <<< ${output}))
	echo "Order id ="${order_id}
	if [[ -z $order_id ]] || [[ ! "$order_id" =~ ^[0-9]+$ ]]
	then
		echo "Could not retrieve order id. Exiting..."
		exit 1
	fi
	check_vol_status ${order_id} ${datacenter} ${node_ip}
	wait
}

# Check and wait until volume order is complete
check_vol_status() {
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Checking status of order id "$1
	echo "Datacenter = "$2
	count=0
	until
		ibmcloud sl block volume-list --order $1 | grep -m 1 $2
	do
		if [[ $count -eq 60 ]]
		then
			# Exiting the loop after 60 iterations (300 secs)
			break
		fi
		ibmcloud sl block volume-list --order $1
		exit_on_error $?
		sleep 5
                count=$((count+1))
	done
	echo "Count = "$count
	if [[ $count -lt 60 ]]
	then
		echo "Block volume order placed successfully. Order $1 is ready. Volume provisioning in progress..."
        else
                echo "Volume order not ready in expected time. Exiting..."
	        exit 1
	fi
	retrive_vol_details $1 $3
}

# Get volume details
retrive_vol_details(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Retriving volume details for order = "$1
	vol_id=$(ibmcloud sl block volume-list --order $1 | awk 'NR==2 {print $1}')
	exit_on_error $?

	#output=`cat vol_list_output.txt`
	#echo "$output"
	#vol_id=($(echo "$output" | awk 'NR==2 {print $1}' ))
	echo "Volume id = "$vol_id
	output=$(ibmcloud sl  block volume-detail $vol_id)
	exit_on_error $?

	#output=`cat vol_detail_output.txt`
	act_trans=$(echo "$output" | awk '/# of Active Transactions/ {print $NF}')
	echo "act_trans = "$act_trans
	until 
		[[ $act_trans == 0 ]]
		#echo "act_trans####### : "$act_trans
	do
		echo "Waiting for volume to be provisioned..."
		sleep 5
		output=$(ibmcloud sl  block volume-detail $vol_id)
		act_trans=$(echo "$output" | awk '/# of Active Transactions/ {print $NF}')
	done

	echo "$output"
	target_ip=($(echo "$output" | grep "Target IP" | awk '{print $3}'))
	lun_id=($(echo "$output" | grep "LUN Id" | awk '{print $3}'))
	echo "lun id = "$lun_id
	echo "target ip = "$target_ip
	access_authorize $vol_id $2
}

# Authorize volume access
access_authorize() {
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Authorize access to volume..."
	echo "Vol id =" $1
	echo  "node ip ="$2
	output=$(ibmcloud sl block access-authorize $1 -p $2)
	exit_on_error $?
	
	#output=`cat access_auth_output.txt`
	echo "$output"
	ip_addr=($(sed 's/[^0-9]*//' <<< ${output}))
	echo "IP Addr = "$ip_addr
	output=$(ibmcloud sl block access-list $vol_id)
	exit_on_error $?
	#output=`cat access_list_output.txt`
	
	echo "$output"
	host_iqn=($(echo "$output" | awk 'NR==2 {print $6}'))
	username=($(echo "$output" | awk 'NR==2 {print $7}'))
	password=($(echo "$output" | awk 'NR==2 {print $8}'))
	create_pv
}

# Create persistent volume
create_pv() {
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating Persistent Volume..."
	zone=${!datacenter}
	echo "Zone = "$zone
	pv_name=pv${!node_ip##*.}${zone}
	echo "pv name = "$pv_name
	sed "s/USERNAME/${username}/;s/HOST_IQN/${host_iqn}/;s/NAME/${pv_name}/;s/PASSWORD/${password}/;s/TARGET_IP/${target_ip}/;s/LUN_ID/${lun_id}/;s/NODE_IP/${!node_ip}/;s/VOL_ID/${vol_id}/;s/STORAGE/${size}/;" pv-template.yaml > ${pv_name}.yaml
	oc apply -f ${pv_name}.yaml
}

# Single zone install
single_zone_install() {
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Starting single zone install..."
	for (( i=1; i<=3; i++ ))
	do
		echo "###################################################################"
		node_ip="node_ip_"$i
		datacenter="datacenter_"$i
		echo "Datacenter ="${!datacenter}
		echo "Node ip = "${!node_ip}
		order_volume ${!datacenter} ${!node_ip}
	done
}

# Multi-zone install
multi_zone_install() {
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Starting multi zone install..."
	zones=$(echo $((no_of_zones+0)))
	for (( i=1; i<=${zones}; i++ ))
	do
		echo "###################################################################"
		datacenter="datacenter_"$i
		node_ip="node_ip_"$i
		echo "Datacenter ="${!datacenter}
		echo "Node ip = "${!node_ip}
		order_volume ${!datacenter} ${!node_ip}		
	done
}

##############################################################
#     Creating Key Protect Service Instance and Root Key     #
##############################################################

# Create Key Protect service instance
create_key_protect(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating Key Protect instance with below details ..."
	echo "Name = "${key_protect_name}
	echo "Pricing = tiered-pricing"
	echo "Location = "${location}
	echo "Resource group = "${resource_group}
	output=$(ibmcloud resource service-instance-create "${key_protect_name}" kms tiered-pricing ${location} -g "${resource_group}"  2>&1)
	exit_on_error $?

	#output=`cat key_protect_output.txt`
	echo "$output"
	if [[ $output == *"OK"* ]]
	then
		#Get the ID of the instance
		kp_instance_id=($(echo "$output" | grep GUID | awk '{print $2}'))
		echo "key_protect instance id = "$kp_instance_id
	else
		echo "Key Protect service instance creation failed with below error. Exiting..."
		echo "${output}"
		exit 1
	fi
        #Add Tag to instance
        ibmcloud resource tag-attach --tag-names "env:$env_name" --resource-name "${key_protect_name}"	
}
	
# Create root key
create_root_key(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating root key..."
	output=$(ibmcloud kp key create ${key_name} -i ${kp_instance_id} 2>&1)
	exit_on_error $?
	#output=`cat key_create_output.txt`
	echo "${output}"
        if [[ $output == *"OK"* ]]
	then
		root_key_id=($(echo "${output}" | fgrep "$key_name" | awk 'NR>1 {print $1}'))
		echo "Key id = "$root_key_id
	else
		echo "Key creation failed with error -"
		echo "$output"
		exit 1
	fi
}

##############################################
#    Create etcd datbase service instance    #
##############################################

# Create etcd database service instance
create_etcd_database(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Provisioning etcd database. This could take few minutes to complete. Please wait..."
	# Update parameters
	sed "s/DISK_ENCRYPT_INSTANCE_CRN/$kp_instance_id/;s/DISK_ENCRYPT_KEY_CRN/$root_key_id/;" etcd-db-template.json > etcd-db-params.json
	output=$(ibmcloud resource service-instance-create "${etcd_db_name}" databases-for-etcd standard us-south --service-endpoints private --parameters @etcd-db-params.json -g ${resource_group})
	exit_on_error $?

	status=($(echo "$output" | awk '/Status/ { print $NF }' ))
	echo "Status = "$status
	check_etcd_db_status
	wait
        #Add Tag to instance
        ibmcloud resource tag-attach --tag-names "env:$env_name" --resource-name "${etcd_db_name}"	
}

# Checking etcd database status
check_etcd_db_status(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Checking Database etcd status..."
	output=""
	count=0
	until
		[[ $(echo "$output" | awk '/Status/ { print $NF }') == "succeeded" ]] || [[ $count -eq 150 ]]
	do
		#output=`cat $output_file`
		output=$(ibmcloud resource service-instance ${etcd_db_name} -g ${resource_group})
		exit_on_error $?

		status=($(echo "$output" | awk '/Status/ { print $NF }'))
		echo "Database etcd provisioning in progress. Please wait..."
		sleep 5
		count=$((count+1))
	done
	if [[ $count -lt 150 ]]
	then
		echo "Database etcd instance provisioned successfully..."
	else
		echo "Database etcd instance provisioning took longer then expected. Exiting..."
	       	exit 1	
	fi
}

# Create service credential
create_service_cred(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating service credential..."
	# Creating service credential for Databases-for-etcd instance
	output=$(ibmcloud resource service-key-create ${service_cred_name} --instance-name ${etcd_db_name})
	exit_on_error $?

	#output=$(cat service_cred_output.txt)
	cmd_status=($(echo "$output" | awk '/OK/ {print $1}'))
	echo "Cmd status = "$cmd_status
	if [[ $cmd_status == "OK" ]]
	then
		echo "Service credential created successfully...."
	else
		echo "Service credential creation failed. Exiting..."
		exit 1
	fi
	uname=($(echo "$output" | awk '/username/ {print $2}'))
	echo "Username: "$uname
	passwd=($(echo "$output" | awk '/password/ {print $2}'))
	echo "Password: "$passwd
	certificate=($(echo "$output" | awk '/certificate_base64/ {print $2}'))
	echo "Certificate: "$certificate
	etcd_endpoints=($(echo "$output" | awk '/composed:/ {print substr($5,13)}'))
	echo "ETCD-Endpoints : "$etcd_endpoints
	# Create px etcd certs secret
	create_px_etcd_secret
}

##############################################
#    		Create Secrets 		     #
##############################################

# Create px etcd certs secret
create_px_etcd_secret(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating px_etcd_secret yaml file..."
	username_base64=$(echo -n "$uname" | base64)
	echo "username_base64: ""$username_base64"
	tmp_pwd=$(echo -n "$passwd" | base64)
	echo "tmp pwd = ""$tmp_pwd"
	password_base64=$(echo $tmp_pwd | tr -d ' ')
        echo "password_base64: "$password_base64	
	sed "s/<certificate_base64>/$certificate/;s/<username_base64>/$username_base64/;s/<password_base64>/$password_base64/;" px-etcd-certs-template.yaml > px-etcd-certs.yaml
}

# Create px ibm secret
create_px_ibm_secret(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating px_ibm_secret yaml file..."
        # Convert username and password to base64
	api_key_base64=($(echo -n $api_key | base64))
	kp_instance_id_base64=($(echo -n $kp_instance_id | base64))

	root_key_id_base64=($(echo -n $root_key_id | base64))
        echo "root_key_id_base64: "$root_key_id_base64
        kp_api_endpoint_base64=($(echo -n $kp_api_endpoint | base64))
        echo "kp_api_endpoint_base64: "$kp_api_endpoint_base64
        sed "s/<api_key_base64>/$api_key_base64/;s/<kp_instance_id_base64>/$kp_instance_id_base64/;s/<root_key_base64>/$root_key_id_base64/;s/<kp_api_endpoint_base64>/$kp_api_endpoint_base64/;" px-ibm-secret-template.yaml > px-ibm-secret.yaml
}

###################################################
#	Create Service ID and assign policies	  #
###################################################

# Create Service ID and assign policies
create_service_id(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating Service ID..."
	output=$(ibmcloud iam service-id-create $service_id_name)
	exit_on_error $?

	#output=$(cat service_id_create_output.txt)
	if [[ $output == *"FAILED"* ]]
	then
		echo "Service ID creation failed with below error message. Exiting..."
		echo "$output"
		exit 1
	fi
	service_id=($(echo "$output" | awk '/ServiceId/ {print $2}'))
	echo "Service id = "$service_id
	
	# Add permissions to service id
	output=($(ibmcloud iam service-policy-create $service_id --roles Reader,Writer,Viewer --service-name kms --service-instance $kp_instance_id))
	exit_on_error $?

	wait
	#output=$(cat add_permissions_output.txt)
	echo "$output"
        if [[ $output == *"FAILED"* ]]
	then
		echo "Service ID creation failed with below error message. Exiting..."
		echo "$output"
		exit 1
	fi
	policy_id=($(echo "$output" | awk '/Policy ID:/ {print $3}'))	
	echo "Policy id = "$policy_id
}

#################################
#	Create API Key		#
#################################
# Create API Key
create_api_key(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Creating API Key..."
	#api_key_name="Dev-Int-API-Key"
	output=$(ibmcloud iam api-key-create $api_key_name -d "API Key used by Portworx to access IBM Key Protect API")
	exit_on_error $?

	#output=$(cat api_create_output.txt)
	echo "$output"
	api_key=($(echo "$output" | grep "API Key" | awk '{NR}END {print $3}'))
	echo "API Key = "$api_key
	create_px_ibm_secret
}

#################################
#	Install Portworx	#
#################################
install_portworx(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Installing Portworx..."
	oc new-project portworx
	oc apply -f px-ibm-secret.yaml -n portworx
	oc get secret all-icr-io -n default -o yaml | sed 's/default/kube-system/g' | oc create -n kube-system -f -
	oc secrets link sa/default all-icr-io -n kube-system --for=pull
	oc describe sa/default -n kube-system
	#api_key="IUG4h1bihdjUuADErsNxyoUbXsYhdcR6cvpw4kTjFJ2G"
	#etcd_endpoints="https://03701112-fd7a-4eb0-94ca-e7d81008c8c2.bn2a2vgd01r3l0hfmvc0.private.databases.appdomain.cloud:30285"
	# Create params json file
	sed "s/API-KEY/$api_key/;s/CLUSTER/$ocp_cluster_name/;s#ETCD-ENDPOINT#$etcd_endpoints#;" portworx-params-template.json > portworx-params.json
	echo "Printing portworx-params.json"
	cat portworx-params.json
	output=$(ibmcloud resource service-instance-create "${portworx_instance_name}" portworx px-dr-enterprise $location --parameters @portworx-params.json -g $resource_group )
	exit_on_error $?

	echo "$output"
	if [[ $output == *"FAILED"* ]]
	then
		echo "Portworx Enterprise service instance provisioning failed. Exiting.."
		exit 1
	fi
	check_portworx_status
	wait
	#Add Tag to instance
	ibmcloud resource tag-attach --tag-names "env:$env_name" --resource-name "${portworx_instance_name}"
	# List Portworx pods
	echo "Listing portworx pods on the cluster..."
	oc get pods -n kube-system | grep portworx
}

# Checking portworx instance status
check_portworx_status(){
	echo "###################################################################"
	echo "$(date "+%Y%m%d%H%M%S"):Checking Portworx instance status..."
	output=""
	count=0
	until
		[[ $(echo "$output" | awk '/Status/ { print $NF }') == "succeeded" ]] || [[ $count -eq 120 ]]
	do
		output=$(ibmcloud resource service-instance "${portworx_instance_name}" -g ${resource_group})
		exit_on_error $?

		status=($(echo "$output" | awk '/Status/ { print $NF }'))
		if [[ status == "failed" ]]
		then
			echo "Portworx Enterprise instance provisioning failed."
			echo "$output"
			exit 1
		fi
		echo "Portworx Enterprise instance provisioning in progress. Please wait..."
		sleep 5
		count=$((count+1))
	done
	if [[ $count -lt 120 ]]
	then
		echo "Portworx Enterprise instance provisioned successfully..."
		echo "Portworx Enterprise instance name = "$portworx_instance_name
	else
		echo "Portworx Enterprise instance provisioning took longer then expected. Exiting..."
	       	exit 1	
	fi
}

login_check
create_node_ip_arr
validate_node_ips
initial_prep_work
check_attacher_plugin

if [[ $enable_order_storage_attach == "true" ]]
then
	# Order storage and attach to nodes
	if [[ ${no_of_zones} -eq 1 ]]
	then
		single_zone_install
	else
		multi_zone_install
	fi
else
	echo "Not installing storage ..."
fi

if [[ $enable_create_key_protect == "true" ]]
then
	create_key_protect

	create_root_key
else
	echo "Not creating Key Protect..."
fi

if [[ $enable_create_etcd_db == "true" ]]
then
	create_etcd_database
	# Create service credentials for etcd database
	create_service_cred
	# Create certs secret on cluster
	oc apply -f px-etcd-certs.yaml -n kube-system
	exit_on_error $?
else
	echo "Not creating etcd database..."
fi

if [[ $enable_create_service_id == "true" ]]
then
	create_service_id
else
	echo "Not creating service id..."
fi

if [[ $enable_create_api_key == "true" ]]
then
	create_api_key
else
	echo "Not creating api key..."
fi

if [[ $enable_install_portworx == "true" ]]
then
	#echo "Disabling portworx installation"
	install_portworx
else
	echo "Not installing portworx.."
fi
echo "####################################################################"
echo "# 	Portworx installation completed successfully		 #"
echo "####################################################################"
echo "$(date "+%Y%m%d%H%M%S"): End installation of Portworx ###############"

