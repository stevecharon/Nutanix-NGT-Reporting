#Requires -PSEdition Core 
#just pasting the shell script here in order to convert it some time
#!/bin/bash
# Script to list Nutanix Guest Tool Status
# Author: Magnus Andersson, Sr Staff Solution Architect @Nutanix.
# Date: 2019-01-10
#
# Version 1.2 - REST API and output adjustments
# Version 1.1 - Limited the script output to display information about which VM is being processed
# Version 1.0 - Initial Release
#
#---------------------------------------
# Define your variables in this section
#---------------------------------------
#
# !!!! Do not remove the two double quotes around the values !!!!
#
# Specify output file directory - Do not include a slash at the end
$directory="$env:USERPROFILE\Documents\script\REST"
#
# Specify Nutanix Cluster FQDN, User and Password
$clusterfqdn="nutanix.$env:USERDNSDOMAIN"
#don't use passwords in your script - implement a safer way like some password vault
#we will use Devolutions RemoteDesktopManager Server as a username/password source since we have it here
#be sure to have access to the entries you are referencing
#if you use other great software for your credentials, implement that, can't help with it, though
user="admin"
passwd="Secret"
$cred=get-rdmsessioncredential $clusterfqdn
#
#-------------------------------------------
# Do not edit anything below this line text
#-------------------------------------------
#
#
# Define Script Global REST API URLs
$urlgetcluster="https://"+$clusterfqdn+":9440/api/nutanix/v2.0/clusters/"
$urlgetvms="https://"+$clusterfqdn+":9440/api/nutanix/v2.0/vms/"
#
#Construct Header
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($cred.UserName+":"+$cred.Password ))
$headers.Add("Accept", "application/json")

# Define Script Global REST API Calls
$getcluster=Invoke-webrequest -k -Credential $cred -Method GET -headers $headers $urlgetcluster
$getvms=Invoke-webrequest -k -Credential $cred -Method GET -headers $headers $urlgetvms`
#
# Find cluster name
$clustername=$getcluster|convertto-json|select entities.name
#
# Get date
#d=`date | awk '{print $3 $2 $6}'`
$datum=(get-date  -F "yyyy-MM-dd")
#
#
# Script output file
file="$directory/"$datum"-Nutanix_Cluster-"$clustername"-VM_Report.csv"
#
# Clean any existing report files with same name as the one being generated
echo > "$file"
#
echo "VM Name,Status,Reachable,Version,Capabilities,ISO Mount State " > "$file"
#
# Get VM uuids
vmuuids=`echo $getvms | python -m json.tool | grep -w uuid | awk -F":" '{print $2}' | awk -F"\"" '{print $2}'`
#
# Create the report
for i in $vmuuids ;
    do
        # Define VM REST API v3 url
        urlgetvm="https://"$clusterfqdn":9440/api/nutanix/v3/vms/$i"
        # Get REST v3 VM info
        vminfo=`curl -s -k -u $user:$passwd -X GET --header 'Accept: application/json' $urlgetvm`
        # Get VM name
        vmname=`echo $vminfo | python -m json.tool |grep -B 2 resources | grep -m 1 name | awk -F "\"" '{print $4}'`
        #
        # Output display message
        echo "Creating reporting input for VM $vmname now ....."
        # Get NGT Info
        ngtstat=`echo $vminfo | python -m json.tool |grep -w -m 1 state | awk -F "\"" '{print $4}' | awk '{print tolower($0)}'`
        # Get VM NGT Status
        ngtstatus=`if [ $ngtstat == "enabled" ] || [ $ngtstat == "disabled" ]
            then
                echo $ngtstat
            else
                echo "N/A"
            fi`
        #echo $ngtstatus
        # Get NGT version
        ngtver=`echo $vminfo | python -m json.tool | grep -w -m 1 version | awk -F "\"" '{print $4}'`
        #ngtver=`echo $vminfo | python -m json.tool |grep -w version | awk -F "\"" '{print $4}'`
        ngtversion=`if [ -z $ngtver ]
            then
                echo "N/A"
            else
                echo $ngtver
            fi`
        # Get NGT ISO info
        ngtisoinfo=`echo $vminfo | python -m json.tool |grep -w -m 1 iso_mount_state | awk -F "\"" '{print $4}' | awk '{print tolower($0)}'`
        #echo $ngtisoinfo
        ngtisomounted=`if [ -z $ngtisoinfo ]
            then
                echo "N/A"
            else
                echo $ngtisoinfo
            fi`
        #echo $ngtisomounted
        # Get NGT Services
        ngtfeatures=`echo $vminfo | python -m json.tool | grep -A 2 -i enabled_capability_list | awk -F "\"" '{print $2}' | grep -v enabled_capability_list | awk 'FNR > 2  {print $0}' | awk '{print tolower($0)}'`
        #echo $ngtfeatures
        ngtcapcheck=`if [[ ! -z $ngtfeatures ]]
            then
                echo $ngtfeatures
            else
                echo "N/A"
            fi`
        #echo $ngtcapcheck
        ngtcapabilities=`if [[ $ngtcapcheck == "self_service_restore" ]] || [[ $ngtcapcheck == "self_service_restore vss_snapshot" ]] || [[ $ngtcapcheck == "vss_snapshot" ]]
            then
                echo $ngtcapcheck
            else
                echo "N/A"
            fi`
        #echo $ngtcapabilities
        # Get Communication status
        ngtcommunication=`echo $vminfo | python -m json.tool |grep -w is_reachable  | awk -F "\ " '{print $2}' | tr -d ','`
        # echo $ngtcommunication
        ngtreachable=`if [ -z $ngtcommunication ]
            then
                echo N/A
            else
                echo $ngtcommunication
            fi`
# Put the information into the report
        echo $vmname,$ngtstatus,$ngtreachable,$ngtversion,$ngtcapabilities,$ngtisomounted >> "$file"
# Closing out the entire script
   done
