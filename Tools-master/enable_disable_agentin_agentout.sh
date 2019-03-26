#! /bin/bash


# Title: Script to delete agent from Config master,Log and Quarantine nodes
# Author: MANASA GADAM SETTY
# Date: 03/25/2018
# Rev: 1.V
# Platform: ANY UNIX

while getopts 'h:a:r:d' OPTION
	do
		case "$OPTION" in
			h)HOST=$(vd find $OPTARG | awk 'BEGIN {FS="."}{print $1}');;
			a)ACTION="$OPTARG";;
			r)RADAR="$OPTARG";;
			d)set -x ;;
			*)
			echo "Script usage: /nas/mtools/bin/enable_disable_agentin_agentout.sh [-h hostname] [-a disable/enable] [-r radar]"
			exit 1;; 
		esac
	done

#Global variable declarations

AGENT=$(vd expand $HOST -l| awk 'BEGIN {FS="="}/nagios.class|host.class/{print $2}' | grep 'agent' 2> /dev/null)
CONFIGMASTER=$(vd expand $HOST -T /configmaster/ -l | awk 'BEGIN {FS="="} {print $2}' 2> /dev/null)
ISTAG=$(vd print $CONFIGMASTER |awk '/service.proofpoint/ {print $1}'|egrep -v "ppsmx$|ppsout$|configmaster$" 2> /dev/null)
PPSNODES=$(vd find --is=/$ISTAG/ -T module.proofpoint.node.type 2> /dev/null)


#Color code declarations

blue="\033[01;34m";
red="\033[01;31m";
green="\033[01;32m";
NC='\033[0m'


ADD_DELETE_AGENT_FROM_CLUSTER() {

if [[ -z $HOST ]] && [[ -z $ACTION ]] && [[ -z $RADAR ]]
then
	echo ' ' 
	echo -e $red "Invalid command line arguments, please use proper command line arguments with options.\n\n***Usage: $0 [-h hostname] [-a disable/enable] [-r radar] *** $NC"
	exit 1 
else
	if [[ $AGENT =~ agent ]] && [[ $ACTION == "disable" ]] && [[ -n $RADAR ]]
	then
		echo ' '
		echo -e $blue "1. Hostname and Command line arguments validation: $green OK $NC [ $AGENT] "
		echo ' '
		echo -e $blue "2. Selected action to perform: $green $ACTION $NC [ $ACTION ]"
		ENABLE_DISABLE_AGENT_IN_VIPS
		exit 0
	elif [[ $AGENT =~ agent ]] && [[ $ACTION == "enable" ]] && [[ -n $RADAR ]]
	then
		echo ' '
		echo -e $blue "1. Hostname validation: $green OK $NC [ $AGENT ]"
		echo ' '
		echo -e $blue "2. Selected action to perform: $green $ACTION $NC [ $ACTION ]"
		ADD_DELETE_AGENT_FROM_CONFIGMASTER_QM_LOG $PPSNODES	
		exit 0
	else
		echo -e $blue "Hostname and Command line arguments validation: $red BAD $NC"
		echo ' '
		exit 1
	fi
fi
}

ENABLE_DISABLE_AGENT_IN_VIPS() {

if [ $ACTION == "disable" ]; then
	echo ' '
	echo -e $red " WARNING: $blue Would you like me to help you disabling HOST $HOST in Vips(YES - Disable in vips / NO - without Disable in Vips, Start deleting HOST from clsuter): \c $NC"
	read ANSWER
	if [ "$ANSWER" == "YES" -o "$ANSWER" == "yes" ]; then
		echo ' '
		echo -e $blue "3. Disabling $HOST in Vips, Please wait for sometime. $NC"
		/nas/mtools/bin/netscaler disable server $HOST > /dev/null 
		if [ $? == "0" ]; then
			echo ' '
			/nas/mtools/bin/netscaler show server $HOST|awk '/Name|IPAddress|Service|State/'
			echo ' '	
			ADD_DELETE_AGENT_FROM_CONFIGMASTER_QM_LOG $PPSNODES
		else
			echo ' ' 
			echo -e $red "**ERROR:** !!!!! MUST HAVE ssh-agent RUNNIGN AND SSH KEYS SETUP !!!!! $NC"
			exit 1
		fi
	else
		echo ' '
		ADD_DELETE_AGENT_FROM_CONFIGMASTER_QM_LOG $PPSNODES
		echo ' '
		
	fi
else
	echo ' '
	echo -e $red " WARNING: $blue Would you like me to help you enabling HOST $HOST in Vips(YES - Enable in vips / NO - Quit) :\c $NC"
	read ANSWER
	if [ "$ANSWER" == "YES" -o "$ANSWER" == "yes" ]; then
		echo ' '
		echo -e $blue "5. Enabling $HOST in Vips, Please wait for sometime. $NC"
		/nas/mtools/bin/netscaler enable server $HOST > /dev/null
		if [ $? == "0" ]; then
			echo ' '
                        /nas/mtools/bin/netscaler show server $HOST|awk '/Name|IPAddress|Service|State/'
                        echo ' '        
                else
                        echo ' ' 
                        echo -e $red "**ERROR:** !!!!! MUST HAVE ssh-agent RUNNIGN AND SSH KEYS SETUP !!!!! $NC"
                        exit 1
                fi
        else
		echo ' '
		echo -e $red "Please make sure to enable HOST $HOST in Vips, before moving back to production $NC"			
             	exit 1
	fi

fi

}

ADD_DELETE_AGENT_FROM_CONFIGMASTER_QM_LOG() {

if [ $ACTION == "disable" ]; then

	for ppsagent in $*
		do
			ssh -o stricthostkeychecking=no -A $ppsagent "sudo /nas/mtools/bin/support_script_for_enable_disable_agentin_agentout.sh $HOST"
		done
else
	for ppsagent in $*
		do
			HOSTTYPE=$(vd print $ppsagent -T module.proofpoint.node.type -l |awk 'BEGIN {FS="="} {print $2}')
			if [ $HOSTTYPE = "config" ]; then
				CFILE=$(ssh -o stricthostkeychecking=no -A $ppsagent "sudo find /opt/proofpoint/current/admin/etc/admind/servers/ -type f -name "*.serv" | grep -i $HOST" 2> /dev/null)
			elif [ $HOSTTYPE = "QM" ]; then
				QMFILE=$(ssh -o stricthostkeychecking=no -A $ppsagent "sudo find /opt/proofpoint/current/admin/etc/admind/servers/ -type f -name "*.serv" | grep -i $HOST" 2> /dev/null)
			elif [ $HOSTTYPE = "LOG" ]; then
				LOGFILE=$(ssh -o stricthostkeychecking=no -A $ppsagent "sudo find /opt/proofpoint/current/admin/etc/admind/servers/ -type f -name "*.serv" | grep -i $HOST" 2> /dev/null)
			fi
		done
			if [[ -z "$CFILE" ]] && [[ -z "$QMFILE" ]] && [[ -z "$LOGFILE" ]]; then 
				echo ' '
				echo -e $red " CRITICAL: Host $HOST is not added in the cluster, we are making changes to add host back to cluster... $NC"
				echo ' '
				ssh -o stricthostkeychecking=no -A $HOST "sudo /nas/mtools/bin/support_script_for_enable_disable_agentin_agentout.sh $HOST"
# One more time validation is required see whether hosts are added back to cluster successfully or not.
				for ppsagent in $*
					do
						if [ $HOSTTYPE = "config" ]; then
						FCFILE=$(ssh -o stricthostkeychecking=no -A $ppsagent "sudo find /opt/proofpoint/current/admin/etc/admind/servers/ -type f -name "*.serv" | grep -i $HOST" 2> /dev/null)
						elif [ $HOSTTYPE = "QM" ]; then
						FQMFILE=$(ssh -o stricthostkeychecking=no -A $ppsagent "sudo find /opt/proofpoint/current/admin/etc/admind/servers/ -type f -name "*.serv" | grep -i $HOST" 2> /dev/null)
						elif [ $HOSTTYPE = "LOG" ]; then
						FLOGFILE=$(ssh -o stricthostkeychecking=no -A $ppsagent "sudo find /opt/proofpoint/current/admin/etc/admind/servers/ -type f -name "*.serv" | grep -i $HOST" 2> /dev/null)
						fi
					done
						if [[ -z "$FCFILE" ]] && [[ -z "$FQMFILE" ]] && [[ -z "$FLOGFILE" ]]; then
							echo ' '
							echo -e $red " CRITICAL: We are FAILED add host back into cluster, please check manually $NC"
							exit 1
						else
							echo ' '
							echo -e $blue "We are successfully moved host back into PSS cluster: $green GOOD $NC [ GOOD ]"
							ENABLE_DISABLE_AGENT_IN_VIPS
						fi
			else
				echo ' '
				echo -e $blue "3. Host $HOST is already added in the cluster: $green GOOD $NC [ GOOD ]"
				ENABLE_DISABLE_AGENT_IN_VIPS
				exit 0
			fi
fi
}	


ADD_DELETE_AGENT_FROM_CLUSTER
