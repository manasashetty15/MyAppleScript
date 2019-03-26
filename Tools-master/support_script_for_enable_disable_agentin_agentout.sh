#!/bin/bash


# Title: Support Script to add or delete agent(in/out) from Config master,Log and Quarantine nodes
# Version: 1.0 

NODE=$1

#Color code declarations

blue="\033[01;34m";
red="\033[01;31m";
green="\033[01;32m";
NC='\033[0m'

AGENT_DELETE_IN_CONFIG_QM_LOG() {

if [ -z "$NODE" -a $# = "0" ]
then
	echo ' '
	echo -e "Please check the script, not working as expected..... "
	echo ' ' 
	exit 1
else
	echo ' '
	NODETYPE=$(vd print $(hostname) -T module.proofpoint.node.type -l |awk 'BEGIN {FS="= "} {print $2}')
	if [[ $NODETYPE == "config" ]]
	then
		echo ' '
		echo -e $blue "Deleting agent $NODE from CONFIG node $(hostname)...... $NC"
		DELETE_AGENT_FROM_CONFIGMASTER
		echo ' '
	elif [[ $NODETYPE == "QM" || $NODETYPE == "LOG" ]]
	then
		echo ' '
		echo -e $blue "Deleting agent $NODE from $NODETYPE node $(hostname)..... $NC"
		DELETE_AGENT_FROM_QURANTINE_AND_LOG_NODE
		echo ' '
	else
		echo -e $blue "4. Preparing to move host back into PPS cluster $NC [config|QM|LOG]"
		ADD_AGENT_TO_CLUSTER
		echo ' '
	fi
fi

}

DELETE_AGENT_FROM_CONFIGMASTER() {

sudo su - pps << EOF
cat /dev/null > /var/tmp/agentlist
/Users/manasa_shetty/tools/showagent.pl > /var/tmp/agentlist
EOF

if [ -s /var/tmp/agentlist ]; then 
	echo ' '
	AGENTNUMBER=$(cat /var/tmp/agentlist |grep -i "$NODE" |awk '{print $1}' | sed -e "s/://")
	cat /var/tmp/agentlist
	echo ' '
	if [ -n "$AGENTNUMBER" ]; then
		echo -e $blue "please verify this carefully, is the same agent would like to delete from configmaster: *** $red $(cat /var/tmp/agentlist |grep -i "$NODE") *** $NC\n"
		echo -e $blue "Please enter $red (yes - proceed further /no - terminate script execution): $NC\c"
		read ANSWER
			if [ $ANSWER == "yes" ]; then
				echo ' '
				echo -e $green "Deleting agent $NODE from configmaster $(hostname)....\n $NC"
				#Real deleteagent action will perform here
				sudo su - pps << EOF
				/opt/proofpoint/current/admin/tools/deleteagent.pl
				yes
				$AGENTNUMBER
EOF
				RESULT=`sudo su - pps << EOF
				/Users/manasa_shetty/tools/showagent.pl | grep -i "$NODE"
EOF`
				if [ -z "$RESULT" ]; then
					echo ' '
					echo -e $green "Successfully removed from cluster $NC"
				else
					echo ' '
					echo -e $red "FAILED to remove from cluster $NC"
					exit 1
				fi
				exit 0
				echo ' '
			else
				echo -e $red "Terminating script execution. please report if you see any issues while running $NC"
				exit 1
			fi
	else
		echo -e $red "Look like $NODE has already removed from the config node $NC"
		exit 1
	fi
else
	echo ' '
	echo -e $red "FILE /var/tmp/agentlist should not be empty, please report for issues $NC"
	exit 1

fi

}

DELETE_AGENT_FROM_QURANTINE_AND_LOG_NODE() {

SERV=$(find /opt/proofpoint/current/admin/etc/admind/servers/$NODE*.serv 2> /dev/null)
if [ -n "$SERV" ]; then
	sudo su - pps << EOF
	mv $(find /opt/proofpoint/current/admin/etc/admind/servers/$NODE*.serv) /var/tmp/
EOF
        FSERV=$(find /opt/proofpoint/current/admin/etc/admind/servers/$NODE*.serv 2> /dev/null)
        if [ -z "$FSERV" ]; then
                echo -e "moving $SERV ---> /var/tmp/ : $green COMPLETED $NC"
                exit 0
        else
                echo -e "moving $SERV ---> /var/tmp/ : $red FAILED $NC"
                exit 1
        fi

else
	echo -e $red ".serv doesn't exist, Look like .serv has already moved to /var/tmp or doesn't exist $NC"
	exit 1
fi
}

ADD_AGENT_TO_CLUSTER() {

sudo su - pps << EOF
/opt/proofpoint/current/admin/tools/deleteagent
yes
EOF

lock="/var/lib/puppet/state/puppetdlock"
server=$(hostname)
echo -e $green "Preparing to run puppet on $server \n $NC"

if [ -e "$lock" ]; then
        echo ' '
        echo -e $red "puppet is already running on the server $server, we will check after 10 seconds..... $NC [sleeping 10 seconds]"
        sleep 10
        echo ' '
        puppet_run_to_make_cluster_changes
        exit 0
else
        echo ' '
        puppet_run_to_make_cluster_changes
        exit 0
fi

}


puppet_run_to_make_cluster_changes() {

	sudo NOOP=false puppet agent -t --detailed-exitcodes > /dev/null 2>&1
	puppetoutput=$?
	while [ $puppetoutput -eq 1 ]
		do
			echo -e $red "puppet is already running on the server $server, we will check after 10 seconds..... $NC [sleeping 10 seconds]"
			sleep 10
                        sudo NOOP=false puppet agent -t --detailed-exitcodes > /dev/null 2>&1
			prunoutput=$?
			if [ $prunoutput -eq 2 ]; then
				echo -e $green "$server: Puppet ran without any errors and made changes $NC [GOOD]"
				break
			elif [ $prunoutput -eq 6 ]; then
				echo -e $red "$server: Puppet ran with errors but made changes $NC [BAD - puppet errors]"
				break
			elif [ $prunoutput -eq 0 ]; then
				echo -e $red "$server: Puppet ran without any errors but made no changes $NC [BAD - puppet errors]"
				break
			elif [ $prunoutput -eq 4 ]; then
				echo -e $red "$server: Puppet ran with errors. please check manually $NC [BAD - puppet errors]"
				break
			fi
		done
	if [ $puppetoutput -eq 2 ]; then
		echo -e $green "$server: Puppet ran without any errors and made changes $NC [GOOD]"
	elif [ $puppetoutput -eq 6 ];then
		echo -e $red "$server: Puppet ran with errors but made changes $NC [BAD - puppet errors]"
	elif [ $puppetoutput -eq 0 ];then
		echo -e $red "$server: Puppet ran without any errors but made no changes $NC [BAD - puppet errors]"
	elif [ $puppetoutput -eq 4 ];then
		echo -e $red "$server: Puppet ran with errors. please check manually $NC [BAD - puppet errors]"
	fi
}


AGENT_DELETE_IN_CONFIG_QM_LOG
