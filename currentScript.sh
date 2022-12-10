#!/bin/bash

#UPDATE SYSTEM
sudo apt-get update && apt-get upgrade
sudo apt-get install gnupg -y

#ADD OPENNEBULA REPO
sudo wget -q -O- https://downloads.opennebula.org/repo/Ubuntu/repo.key | sudo apt-key add -
echo "deb https://downloads.opennebula.org/repo/5.6/Ubuntu/18.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 592F7F0585E16EBF

#INSTALL OPENNEBULA CLI
sudo apt update
sudo apt-get install -y opennebula-tools

#GENERATE SSH
yes '' | ssh-keygen -P $SSHPASS

#START SSH AGENT
eval $(ssh-agent -s)

#CUSER=tope8396
#CPASS="Slaptazodis22"
CENDPOINT=https://grid5.mif.vu.lt/cloud3/RPC2

#CREATE WEBSERVER-VM
echo Getting ready to setup webserver-vm
CVMREZ=$(onetemplate instantiate "debian-11-lxde-django-react" --name "webserver-vm" --user $CUSER --password $CPASS --endpoint $CENDPOINT --cpu 0.1 --memory 1024 --ssh ~/.ssh/id_rsa.pub --net_context)
CVMID=$(echo $CVMREZ |cut -d ' ' -f 3)

#COUNTDOWN
secs=$((60))
while [ $secs -gt 0 ]; do
   echo -ne "Waiting for VM to run $secs\033[0K\r"
   sleep 1
   : $((secs--))
done

#GET AND SAVE VM DETAILS
$(onevm show $CVMID --user $CUSER --password $CPASS --endpoint $CENDPOINT >$CVMID.txt)
CSSH_CON=$(cat $CVMID.txt | grep CONNECT\_INFO1 | cut -d '=' -f 2 | tr -d '"'|sed 's/'$CUSER'/root/')
CSSH_PRIP_WB=$(cat $CVMID.txt | grep PRIVATE\_IP | cut -d '=' -f 2 | tr -d '"')
WB_PUBLIC_IP=$(cat $CVMID.txt | grep PUBLIC\_IP | cut -d '=' -f 2 | tr -d '"')
CSSH_PORTS_WB=$(cat $CVMID.txt | grep TCP\_PORT\_FORWARDING | cut -d '=' -f 2 | tr -d '"')
ARRAY_OF_PORTS=$(echo $CSSH_PORTS_WB | tr : ' ')
read -a SPLITTED_PORTS <<< "$ARRAY_OF_PORTS"
DJANGO_PORT=$(echo "${SPLITTED_PORTS[4]}")
REACT_PORT=$(echo "${SPLITTED_PORTS[6]}")

#DISPLAY VM DETAILS
echo "Successfull if you see details below:"
echo "Connection string: $CSSH_CON"
echo "Local IP: $CSSH_PRIP_WB"
echo "Website's URL: ${WB_PUBLIC_IP}:${REACT_PORT}"

#SSH_COPY_WB="${CUSER}@${CSSH_PRIP_WB}"

#CREATE DATABASE-VM
echo Getting ready to setup database-vm
CVMREZ=$(onetemplate instantiate "debian11-lxde" --name "database-vm" --user $CUSER --password $CPASS --endpoint $CENDPOINT --cpu 0.1 --memory 1024 --ssh ~/.ssh/id_rsa.pub --net_context)
CVMID=$(echo $CVMREZ |cut -d ' ' -f 3)

#COUNTDOWN
secs=$((60))
while [ $secs -gt 0 ]; do
   echo -ne "Waiting for VM to run $secs\033[0K\r"
   sleep 1
   : $((secs--))
done

#GET AND SAVE VM DETAILS
$(onevm show $CVMID --user $CUSER --password $CPASS --endpoint $CENDPOINT >$CVMID.txt)
CSSH_CON=$(cat $CVMID.txt | grep CONNECT\_INFO1 | cut -d '=' -f 2 | tr -d '"'|sed 's/'$CUSER'/root/')
CSSH_PRIP_DB=$(cat $CVMID.txt | grep PRIVATE\_IP | cut -d '=' -f 2 | tr -d '"')

#DISPLAY VM DETAILS
echo "Successfull if you see details below:"
echo "Connection string: $CSSH_CON"
echo "Local IP: $CSSH_PRIP_DB"
SSH_COPY_DB="${CUSER}@${CSSH_PRIP_DB}"

#CREATE CLIENT-VM
echo Getting ready to setup client-vm
CVMREZ=$(onetemplate instantiate "debian11-lxde" --name "client-vm" --user $CUSER --password $CPASS --endpoint $CENDPOINT --cpu 0.1 --memory 1024 --ssh ~/.ssh/id_rsa.pub --net_context)
CVMID=$(echo $CVMREZ |cut -d ' ' -f 3)

#COUNTDOWN
secs=$((60))
while [ $secs -gt 0 ]; do
   echo -ne "Waiting for VM to run $secs\033[0K\r"
   sleep 1
   : $((secs--))
done

#GET AND SAVE VM DETAILS
$(onevm show $CVMID --user $CUSER --password $CPASS --endpoint $CENDPOINT >$CVMID.txt)
CSSH_CON=$(cat $CVMID.txt | grep CONNECT\_INFO1 | cut -d '=' -f 2 | tr -d '"'|sed 's/'$CUSER'/root/')
CSSH_PRIP_CL=$(cat $CVMID.txt | grep PRIVATE\_IP | cut -d '=' -f 2 | tr -d '"')

#DISPLAY VM DETAILS
echo "Successfull if you see details below:"
echo "Connection string: $CSSH_CON"
echo "Local IP: $CSSH_PRIP_CL"
SSH_COPY_CL="${CUSER}@${CSSH_PRIP_CL}"

#ADD PPA AND INSTALL ANSIBLE
echo 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu focal main' | sudo tee -a /etc/apt/sources.list >/dev/null
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
sudo apt update
sudo apt install -y ansible

#REMOVE CONTENTS OF HOSTS FILE AND POPULATE WITH NEW VALUES
yes '' | sudo truncate -s 0 /etc/ansible/hosts
echo '[webserver]' | sudo tee -a /etc/ansible/hosts >/dev/null
echo "root@$CSSH_PRIP_WB" | sudo tee -a /etc/ansible/hosts >/dev/null
echo | sudo tee -a /etc/ansible/hosts >/dev/null
echo '[database]' | sudo tee -a /etc/ansible/hosts >/dev/null
echo "root@$CSSH_PRIP_DB" | sudo tee -a /etc/ansible/hosts >/dev/null
echo | sudo tee -a /etc/ansible/hosts >/dev/null
echo '[client]' | sudo tee -a /etc/ansible/hosts >/dev/null
echo "root@$CSSH_PRIP_CL" | sudo tee -a /etc/ansible/hosts >/dev/null

#INSTALL GIT AND CLONE REPOSITORIES
sudo apt install -y git
git clone https://github.com/tmsptr/websockets-django-react.git
git clone https://github.com/tmsptr/db-vm-websockets.git
git clone https://github.com/tmsptr/ansible-scripts-websockets.git 

#SET FRONT-BACK VARIABLES
echo "PRIVATE_IP=$CSSH_PRIP_DB" >> /home/tope8396/websockets-django-react/backend/chat/.env
echo "DATABASE_PORT=5432" >> /home/tope8396/websockets-django-react/backend/chat/.env
echo "REACT_APP_WEBSERVER_IP=$WB_PUBLIC_IP" >> /home/tope8396/websockets-django-react/frontend/.env
echo "REACT_APP_WEBSERVER_PORT=$DJANGO_PORT" >> /home/tope8396/websockets-django-react/frontend/.env


#RUN PLAYBOOKS FOR VMs
ansible-playbook ./ansible-scripts-websockets/database.yml
ansible-playbook ./ansible-scripts-websockets/webserver.yml
ansible-playbook ./ansible-scripts-websockets/client.yml