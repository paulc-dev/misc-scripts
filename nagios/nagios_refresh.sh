#!/bin/bash
# This script will auto-populate Nagios configuration files by querying AWS for 
# app servers running on Linux. It differenciates between Test and
# Prod app servers.

working_path=/scripts
nagios_path=/usr/local/nagios

# Each time this function is called, it appends a new host definition to a 
# temp file.
writeHostCfg ()
{
   hostname="$1"
   IP="$2"
   serverType="$3"
   envType="$4"
   
   if [ "$serverType" = "linux-app" ]; then
      hostDefinition="# $hostname Application server ($IP)
define host{
      use             linux-app-server
      host_name       $hostname
      alias           $hostname
      address         $IP
      hostgroups      linux-app-servers
      }\n\n"
	  if [ "$envType" = "prod" ]; then
	     echo -e "$hostDefinition" >> linuxProdAppDefinition.txt
		 
		 if [ -f "/scripts/linuxProdAppHostnames.txt" ]; then
            echo -n ",$hostname" >> linuxProdAppHostnames.txt
         else
            echo -n "$hostname" >> linuxProdAppHostnames.txt
         fi   
	  elif [ "$envType" = "nonprod" ]; then
         echo -e "$hostDefinition" >> linuxNonProdAppDefinition.txt
		 
		 if [ -f "/scripts/linuxNonProdAppHostnames.txt" ]; then
            echo -n ",$hostname" >> linuxNonProdAppHostnames.txt
         else
            echo -n "$hostname" >> linuxNonProdAppHostnames.txt
         fi   
	  fi
   fi
}

# When this function is called it generates a temp file with the hostnames
# and services they will be monitored for.
writeServiceCfg()
{
   hostType="$1"
   envType="$2"
   if [ "$hostType" = "linux-app" ]; then
      if [ "$envType" = "prod" ]; then
	     linuxProdAppHostnames=`cat linuxProdAppHostnames.txt`
         cp linuxProdAppTemplate.txt linuxProdAppTemplate-current.txt
         sed -i "s/hosts/$linuxProdAppHostnames/g" linuxProdAppTemplate-current.txt
		 rm -f linuxProdAppHostnames.txt
	  elif [ "$envType" = "nonprod" ]; then
         linuxNonProdAppHostnames=`cat linuxNonProdAppHostnames.txt`
         cp linuxNonProdAppTemplate.txt linuxNonProdAppTemplate-current.txt
         sed -i "s/hosts/$linuxNonProdAppHostnames/g" linuxNonProdAppTemplate-current.txt	  
		 rm -f linuxNonProdAppHostnames.txt
	  fi
   fi

}

# These commands will output a list of internal IP addresses and AWS instance
# names to a file. Instances are filtered by their tags.
aws ec2 describe-instances --filters  "Name=tag:function,Values=application" "Name=tag:environment,Values=prod" "Name=tag:os,Values=linux" "Name=availability-zone,Values=us-east-1a,us-east-1c" --query "Reservations[].Instances[].[PrivateIpAddress, Tags[?Key=='Name'].Value]" --output text >> "$working_path"/linuxProdHosts.txt

aws ec2 describe-instances --filters  "Name=tag:function,Values=application" "Name=tag:environment,Values=test,dev" "Name=tag:os,Values=linux" "Name=availability-zone,Values=us-east-1a,us-east-1c" --query "Reservations[].Instances[].[PrivateIpAddress, Tags[?Key=='Name'].Value]" --output text >> "$working_path"/linuxNonProdHosts.txt

# Check that the file has an even number of lines and if so, read all the 
# lines into an array. Each pair of lines will be a AWS instance name and IP.
# This will create an array of linux prod hosts
num_lines=$(wc -l < "$working_path"/linuxProdHosts.txt)
if [ $((num_lines%2)) -eq 0 ]; then
   i=0
   while IFS= read -r line; 
   do
      prodHostArray[ $i ]="$line"
      i=$((i+1))
   done <linuxProdHosts.txt
else
   echo The list of Prod app servers was not generated correctly, exiting...
   exit
fi

# This will create an array of linux non-prod hosts
num_lines=$(wc -l < $working_path/linuxNonProdHosts.txt)
if [ $((num_lines%2)) -eq 0 ]; then
   i=0
   while IFS= read -r line; 
   do
      nonProdHostArray[ $i ]="$line"
      i=$((i+1))
   done <linuxNonProdHosts.txt
else
   echo The list of Non-Prod app servers was not generated correctly, exiting...
   exit
fi

# Iterate through the lists of prod hosts and call the function to create a
# host definition for each host, passing the server type and environment type
for ((i=0; i < "${#prodHostArray[@]}"; i++))
do
   IP=${prodHostArray[i]}
   i=$((i+1))
   hostname=${prodHostArray[i]}
   writeHostCfg $hostname $IP "linux-app" "prod"
done

# Iterate through the lists of non-prod hosts and call the function to create a
# host definition for each host, passing the server type and environment type
for ((i=0; i < "${#nonProdHostArray[@]}"; i++))
do
   IP=${nonProdHostArray[i]}
   i=$((i+1))
   hostname=${nonProdHostArray[i]}
   writeHostCfg $hostname $IP "linux-app" "nonprod"
done

# Once the temp host definition files are created, call the functions to create
# the service definitions for each set of hosts
writeServiceCfg "linux-app" "prod"
writeServiceCfg "linux-app" "nonprod"

# Generate the final config file for each env type by concatenating the temp
# host definition and service definition files
cat linuxProdAppDefinition.txt linuxProdAppTemplate-current.txt > linux-prod-app.cfg
cat linuxNonProdAppDefinition.txt linuxNonProdAppTemplate-current.txt > linux-non-prod-app.cfg

# Remove all the temp files that were used
rm -f linuxNonProdAppDefinition.txt linuxNonProdAppTemplate-current.txt linuxNonProdAppHosts.txt
rm -f linuxProdAppDefinition.txt linuxProdAppTemplate-current.txt linuxProdAppHosts.txt

rm -f $working_path/linuxProdHosts.txt
rm -f $working_path/linuxNonProdHosts.txt

# Backup the existing config files, modify and modify the permissions.
mv /usr/local/nagios/etc/objects/linux-prod-app.cfg /usr/local/nagios/etc/objects/linux-prod-app.cfg.bak
mv /usr/local/nagios/etc/objects/linux-non-prod-app.cfg /usr/local/nagios/etc/objects/linux-non-prod-app.cfg.bak
chown nagios:nagios /usr/local/nagios/etc/objects/linux-prod-app.cfg.bak
chown nagios:nagios /usr/local/nagios/etc/objects/linux-non-prod-app.cfg.bak
chmod 664 /usr/local/nagios/etc/objects/linux-prod-app.cfg.bak
chmod 664 /usr/local/nagios/etc/objects/linux-non-prod-app.cfg.bak

# Move the generated config files to their final location and modify the
# permissions.
mv linux-prod-app.cfg /usr/local/nagios/etc/objects
mv linux-non-prod-app.cfg /usr/local/nagios/etc/objects
chown nagios:nagios /usr/local/nagios/etc/objects/linux-prod-app.cfg
chown nagios:nagios /usr/local/nagios/etc/objects/linux-non-prod-app.cfg
chmod 664 /usr/local/nagios/etc/objects/linux-prod-app.cfg
chmod 664 /usr/local/nagios/etc/objects/linux-non-prod-app.cfg

echo "The nagios config files have been written..."
# Run a nagios configuration check and give the option to apply the changes or
# revert.
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
echo "********************************************"
echo "********************************************"
while true; do
    read -p "Do you want to restart the Nagios service? " yn
    case $yn in
        [Yy]* ) systemctl restart nagios.service 
                break;;
        [Nn]* ) mv /usr/local/nagios/etc/objects/linux-prod-app.cfg.bak /usr/local/nagios/etc/objects/linux-prod-app.cfg
		        mv /usr/local/nagios/etc/objects/linux-non-prod-app.cfg.bak /usr/local/nagios/etc/objects/linux-non-prod-app.cfg
                exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
