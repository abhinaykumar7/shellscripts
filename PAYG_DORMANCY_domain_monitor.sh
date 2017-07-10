#! /bin/ksh
#******************************************************************************#
# Monitor script for the PAYG DORMANCY domain.                                 #
# Praveen - 09/06/17							       #
################################################################################
#                                                                              #
#* Version    Modified By     Date              Description                    #
#******************************************************************************#
#   1.0       Praveen        09/06/2017         Initial version                #
################################################################################

# Set up environment
# The following directories represent the states that a batch can progress through
# there will be either a main batch file 
# the batch in the appropriate directory for the state of the batch

# PAYG_DORMANCY_DOMAIN are provided in the environment

PROCESSING_DIR=$PAYG_DORMANCY_DOMAIN"/Processing"
ARCHIVE_DIR=$PAYG_DORMANCY_DOMAIN/"Archive"
ERROR_DIR=$PAYG_DORMANCY_DOMAIN"/Error"
INPUT_DIR=$PAYG_DORMANCY_DOMAIN"/Input"

DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

# Infinite monitoring loop
while [ INFINITE ]
do
	# First determine the state of the domain process itself
	if [ $(ps eax | grep -e PAYG_DORMANCY_domain.sh | grep -v grep | grep -v start_PAYG_DORMANCY_domain.sh | wc -l) -ne 0 ]
	then
		STATUS="RUNNING"
	else
		if [ -f $PAYG_DORMANCY_DOMAIN"/STOP" ]
		then
			STATUS="SUSPENDED"
		else
			STATUS="NOT RUNNING"
		fi
	fi
	
	# Count the number of processes associated with the domain (but not including the
	# monitor processes).
	
	NUM_DOMAIN_PROCS=$(ps -fu $(whoami) | grep PAYG_DORMANCY | grep -v grep | grep -v domain_monitor | wc -l)

	# Now list the contents of the various directories - could use find from the 
	# PAYG_DORMANCY_DOMAIN directory, but have decided to display each directory individually.

	cd $PAYG_DORMANCY_DOMAIN
	
	# The following will extract a list of files in each of the state directories and the
	
        ERROR_LIST=$(ls -lrt $ERROR_DIR | awk '{print $9}')
        PROCESSING_LIST=$(ls -lrt $PROCESSING_DIR | awk '{print $9}')
        INPUT_LIST=$(ls -lrt $INPUT_DIR | awk '{print $9}')
        ARCHIVE_LIST=$(ls -lrt $ARCHIVE_DIR | awk '{print $9}')

	
	# Display header of monitor
	clear
	echo "                        PAYG DORMANCY domain Monitor"
	echo "                        ----------------------------"
	echo
	echo "Current date/time:" $(date +"%d-%m-%Y %H:%M") "		Status:	$STATUS"
	echo "Number of active processes: $NUM_DOMAIN_PROCS"
	echo "Batch					Items		Time"
	echo "========================================================================"
	
	# Now display the contents of the state directories
	
	if [ "$INPUT_LIST" != "" ]
	then
		echo "INPUT FILES:"
                echo "$INPUT_LIST"
		echo "------------------------------------------------------------------------"
	fi

	if [ "$ARCHIVE_LIST" != "" ]
	then
		echo "ARCHIVED FILES :"
                echo "$ARCHIVE_LIST"
		echo "------------------------------------------------------------------------"
	fi
        if [ "$ERROR_LIST" != "" ]
        then
                echo "ERROR FILES:"
                echo "$ERROR_LIST"
                echo "------------------------------------------------------------------------"
        fi
        if [ "$PROCESSING_LIST" != "" ]
        then
                echo "PROCESSING FILES:"
                echo "$PROCESSING_LIST"
                echo "------------------------------------------------------------------------"
        fi


	sleep 10
done
