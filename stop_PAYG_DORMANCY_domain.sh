#! /bin/ksh
################################################################################
# Stop script for the PAYG Dormnacy domain.                                    #
#                                                                              #
# This script provides a single stop script for the PAYG Dormnacy domain -     #
#                                                                              #
################################################################################
#* Usage: stop_PAYG_DORMANCY_domain.sh.sh                                      *
#*                                                                             *
#* Version    Modified By     Date              Description                    *
#*******************************************************************************
#*  1.0       Abhinay        28-02-2017         Initial Version                *
#*******************************************************************************

# Set up environment

DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"
# Create the stop file and write in the log that it's been done
echo >> $DOMAIN_LOG
echo "$(date):$(basename $0) - domain stop requested..." >> $DOMAIN_LOG
echo >> $DOMAIN_LOG

echo "$(date):$(basename $0) - Creating stop files..." >> $DOMAIN_LOG
touch $PAYG_DORMANCY_DOMAIN"/STOP"
touch $PAYG_DORMANCY_DOMAIN"/STOP_rec_processor"
touch $PAYG_DORMANCY_DOMAIN"/STOP_rsp_collector"
#Kill response domain

PROCESS_DETAILS=$(ps -ef | grep paygDormancyRSPDaemon.tcl | grep -v grep | awk {'print$2"-"$9'})

if [[ ! -z "${PROCESS_DETAILS// }" ]];
then
	echo "$(date):$(basename $0) - Killing response daemon..." >> $DOMAIN_LOG
  	for PROCESS_DETAIL in $PROCESS_DETAILS
	do
  		PROCESS_DETAIL_ARRAY=($(echo $PROCESS_DETAIL | tr "-" " "))
		echo "$(date):$(basename $0) - Killing the process : ${PROCESS_DETAIL_ARRAY[1]}  " >> $DOMAIN_LOG
		echo "$(date):$(basename $0) - Process ID : ${PROCESS_DETAIL_ARRAY[0]} " >> $DOMAIN_LOG
    		kill -9 ${PROCESS_DETAIL_ARRAY[0]}
	done
	unset PROCESS_DETAIL_ARRAY
fi
 
