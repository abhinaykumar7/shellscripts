#! /bin/ksh
################################################################################
# Start script for the PAYG Dormancy domain.                                   #
#                                                                              #
# This script provides a single start script for the PAYG Dormancy domain      #
# which is implemented as a shell script running as a background process.      #
# In addition to checking that the domain isn't already running (a check also  #
# carried out by the process itself for safetys sake), this script will also   #
# ensure that the domain is brought up as a nohup'd background process with any#
# output from the domain being directed to a log file.                         #
#                                                                              #
################################################################################
#* Usage: start_PAYG_DORMANCY_domain.sh                                        *
#*                                                                             *
#* Version    Modified By     Date              Description                    *
#*******************************************************************************
#*  1.0       Abhinay        23-05-2017         Initial Version                *
#*******************************************************************************

# Set up environment


DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

# Given that the domain is being explicitly started, remove the STOP file
rm -f $PAYG_DORMANCY_DOMAIN"/STOP"
rm -f $PAYG_DORMANCY_DOMAIN"/STOP_rec_processor"
rm -f $PAYG_DORMANCY_DOMAIN"/STOP_rsp_collector"

# Next, check that the domain process isn't running already - check lock file and also
# look through the process list.

if [ $(ps eax | grep PAYG_DORMANCY_domain.sh | grep -v grep | grep -v start_PAYG_DORMANCY_domain.sh | wc -l) -ne 0 ]
then
	echo
	echo "The PAYG_DORMANCY_domain.sh is already running."
	echo "Cannot start another instance."
	exit 1
elif [ -f $PAYG_DORMANCY_DOMAIN"/domain_lock.sts" ]
then
	# Safety feature to ensure that operator is going out of their way to start the
	# domain if a lock file exists - reducing accidental starts.
	echo
        echo "Can't find a running PAYG_DORMANCY_domain.sh process but the $PAYG_DORMANCY_DOMAIN"/domain_lock.sts" lock"
        echo "file is present. Please remove this file before re-attempting to start the"
        echo "domain."
        echo
        exit 1
fi

# Got to here and so is OK to start the domain.
echo "$(date):$(basename $0) - domain start requested..." >> $DOMAIN_LOG
nohup $PAYG_DORMANCY_DOMAIN"/PAYG_DORMANCY_domain.sh" >> $DOMAIN_LOG 2>&1 &

echo
echo "PAYG_DORMANCY_domain started..."
echo
