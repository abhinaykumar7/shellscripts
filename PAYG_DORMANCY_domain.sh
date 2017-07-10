#! /bin/ksh
#*******************************************************************************
#* Name : PAYG_DORMANCY_domain.sh                                              *
#*                                                                             *
#* Description:This script is the controller script for PAYG Dormancy, it runs *
#*             as daemon                                                       *
#*                                                                             *
#* Usage: PAYG_DORMANCY_domain.sh                                              *
#*                                                                             *
#* Version    Modified By     Date              Description                    *
#*******************************************************************************
#*  1.0       Abhinay        28-05-2017         Initial Version                *
#*                                                                             *
#******************************************************************************* 

# Set up environment

INPUT_DIR=$PAYG_DORMANCY_DOMAIN"/Input"
PROCESSING_DIR=$PAYG_DORMANCY_DOMAIN"/Processing"
ARCHIVE_DIR=$PAYG_DORMANCY_DOMAIN"/Archive"
OUTPUT_DIR=$PAYG_DORMANCY_DOMAIN"/Output"
TERTIO_REPORT_DIR=$PAYG_DORMANCY_DOMAIN"/tertio_report"
ERROR_DIR=$PAYG_DORMANCY_DOMAIN"/Error"

DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

LOCK_FILE=$PAYG_DORMANCY_DOMAIN"/domain_lock.sts"
LOCK_FILE_RSP_COLL=$PAYG_DORMANCY_DOMAIN"/domain_lock_rsp_collector.sts"
LOCK_FILE_RSP_PROC=$PAYG_DORMANCY_DOMAIN"/domain_lock_rec_processor.sts"

# Load file details to DB
DB_UNAME=$(awk -F= '/^UserName/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_PASSWORD=$(awk -F= '/^Password/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_CONNECT_STRING=$DB_UNAME/$DB_PASSWORD


if [ -f $LOCK_FILE ]
then
	# Obviously not starting it using the start script and so echo to stdout
	echo >> $DOMAIN_LOG
	echo "$(date):$(basename $0) - $LOCK_FILE exists, indicating that domain is already running" >> $DOMAIN_LOG
	echo "$(date):$(basename $0) - Please use start_PAYG_DORMANCY_domain.sh to start the domain" >> $DOMAIN_LOG
	echo >> $DOMAIN_LOG
	return 9
fi

# Indicate that the domain is starting by creating a lock file
touch $LOCK_FILE

# Initiate loop - this is an infinite loop whose job is simply to progress batches through
# the state machine. 

while [ INFINTE ]
do
	DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

	if [ -f $PAYG_DORMANCY_DOMAIN"/STOP" ]
	then
		echo "$(date):$(basename $0) - domain shutting down..." >> $DOMAIN_LOG
		rm $LOCK_FILE
		return 0
	fi

	cd $INPUT_DIR
	RECEIVED_FILES=$(ls -lrt * 2> /dev/null | tr -d '@' | awk '{print $9}')
	cd -

	NUM_RECEIVED_FILES=$(echo $RECEIVED_FILES | wc -w)

	TEMP_FILE=$PAYG_DORMANCY_DOMAIN"/Processing/domaintemp.txt"



	cd $PAYG_DORMANCY_DOMAIN/batchSOproc/source
	echo "$(date):$(basename $0) INFO - Starting response consumer" >> $DOMAIN_LOG

		nohup gmi2_reponse_consumer.ksh 2>> $DOMAIN_LOG &
	cd - 	


	# response collector
	if [ ! -f $LOCK_FILE_RSP_COLL ]
	then
        	echo >> $DOMAIN_LOG
		echo "$(date):$(basename $0) INFO - $LOCK_FILE_RSP_COLL does not exist, starting response collector" >> $DOMAIN_LOG
        	echo >> $DOMAIN_LOG
		nohup $PAYG_DORMANCY_DOMAIN"/"PAYG_DORMANCY_response_collector.sh 2>> $DOMAIN_LOG &
		echo "$(date):$(basename $0) INFO - Response collector started" >> $DOMAIN_LOG
	else
		echo "$(date):$(basename $0) INFO - Response collector is already running" >> $DOMAIN_LOG
	
	fi


	#response processor	
	if [ ! -f $LOCK_FILE_RSP_PROC ]
	then
        	echo >> $DOMAIN_LOG
		echo "$(date):$(basename $0) INFO - $LOCK_FILE_RSP_PROC does not exist, starting response processor" >> $DOMAIN_LOG
        	echo >> $DOMAIN_LOG
		nohup $PAYG_DORMANCY_DOMAIN"/"PAYG_DORMANCY_process_records.sh 2>> $DOMAIN_LOG &	
		echo "$(date):$(basename $0) INFO - Response processor started" >> $DOMAIN_LOG
	else
		echo "$(date):$(basename $0) INFO - Response processor is already running" >> $DOMAIN_LOG
	fi

	# Check if load and validate is running
	SLEEP_DURATION=$(awk -F= '/^DURATION_SLEEP_DOMAIN/ {print $2}' ${PAYG_DORMANCY_DOMAIN}/config_param.file)	

	if [ $NUM_RECEIVED_FILES -gt 0 ]
	then
		echo "$(date):$(basename $0) INFO - There are files ..$NUM_RECEIVED_FILES.. in input directory" >> $DOMAIN_LOG

		for FILE_TO_PROC in $RECEIVED_FILES
		do
			echo "$(date):$(basename $0) INFO - Invoking load and validate script for $FILE_TO_PROC" >> $DOMAIN_LOG
			$PAYG_DORMANCY_DOMAIN"/"PAYG_DORMANCY_load_validate.sh $FILE_TO_PROC
		done 


		#echo "$(date):$(basename $0) INFO - Sleep for $SLEEP_DURATION  second before reports are generated " >> $DOMAIN_LOG
		#sleep $SLEEP_DURATION
		echo "$(date):$(basename $0) INFO - Validated and loaded all files in queue, will generate report for all files in batch" >> $DOMAIN_LOG
	
		REPORT_NAME=$PAYG_DORMANCY_DOMAIN"/Processing/DormancyDataLoadingReport-$(date "+%Y%m%d")-$(date "+%H%M%S")"
		DTIME=`date "+%d%m%Y-%H%M%S"`
		echo "Date=$DTIME" > $REPORT_NAME

		echo >> $REPORT_NAME
		echo "$(date):$(basename $0) INFO - Total number of files processed in last scan : $NUM_RECEIVED_FILES" >> $DOMAIN_LOG
		echo "Number of files processed = $NUM_RECEIVED_FILES" >> $REPORT_NAME
		echo >> $REPORT_NAME
		FILES_IN_LAST_SCAN=$(echo $RECEIVED_FILES | sed -e 'y/ /\n/')
		echo "$(date):$(basename $0) INFO - List of files processed in last scan : $FILES_IN_LAST_SCAN" >> $DOMAIN_LOG
		echo "List of files processed =" >> $REPORT_NAME
		echo "$FILES_IN_LAST_SCAN" >> $REPORT_NAME
		echo >> $REPORT_NAME

		if [ $NUM_RECEIVED_FILES -eq 1 ]
		then

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select count(*)|| ':' from  payg_dormancy_req_tracking where batch_filename ='$FILES_IN_LAST_SCAN' ;
EOF

			MSISDNS_LOADED_IN_LAST_SCAN="$(cat $TEMP_FILE | cut -f1 -d':')"
			echo "Number of MSISDNs loaded successfully = $MSISDNS_LOADED_IN_LAST_SCAN" >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - MSISDNs successfully loaded in last scan ..$MSISDNS_LOADED_IN_LAST_SCAN" >> $DOMAIN_LOG
			echo "SQL Query  "  >> $DOMAIN_LOG
			echo "select count(*)|| ':' from  payg_dormancy_req_tracking where batch_filename ='$FILES_IN_LAST_SCAN'"  >> $DOMAIN_LOG
			echo >> $REPORT_NAME

			cat $TEMP_FILE >> $DOMAIN_LOG

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select count(*)|| ':' from  payg_dormancy_req_tracking where batch_filename = '$FILES_IN_LAST_SCAN' and state is null;
EOF

			TOTAL_MSISDN_PENDING="$(cat $TEMP_FILE | cut -f1 -d':')"
			echo "Total number of MSISDNs pending for termination held within Tertio db = $TOTAL_MSISDN_PENDING" >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - Total number of MSISDNs pending for termination held within Tertio db = $TOTAL_MSISDN_PENDIN" >> $DOMAIN_LOG
			echo >> $REPORT_NAME

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select count(*)|| ':' from  payg_dormancy_req_tracking where batch_filename = '$FILES_IN_LAST_SCAN' and state ='Rejected' and substr(result,1,4) in('9007','9008','9009');
EOF


			TOTAL_MSISDN_REJECTED="$(cat $TEMP_FILE | cut -f1 -d':')"
			echo "Number of MSISDNs rejected for loading = $TOTAL_MSISDN_REJECTED" >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - Number of MSISDNs rejected for loading = $TOTAL_MSISDN_REJECTED" >> $DOMAIN_LOG
			cat $TEMP_FILE >>  $DOMAIN_LOG
			echo >> $REPORT_NAME

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select batch_filename|| ',' || msisdn || ',' || accountid ||','||retirement_reason ||',' || category ||',' ||substr(result,7)  from  payg_dormancy_req_tracking where batch_filename ='$FILES_IN_LAST_SCAN' and state ='Rejected' and substr(result,1,4) in('9007','9008','9009');
EOF

			cat $TEMP_FILE >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - MSISDNs rejected for loading " >> $DOMAIN_LOG
			cat $TEMP_FILE	
			cat $TEMP_FILE	 >> $DOMAIN_LOG

			echo "$(date):$(basename $0) INFO - Copying $REPORT_NAME to $ARCHIVE_DIR and moving to $OUTPUT_DIR" >> $DOMAIN_LOG
			cp $REPORT_NAME $ARCHIVE_DIR	
			mv $REPORT_NAME $OUTPUT_DIR

		else	
			echo "$(date):$(basename $0) INFO - More than one file received for which report needs to be generated " >> $DOMAIN_LOG
			PATT="','"
			FILES_IN_LAST_SCAN=$(echo $RECEIVED_FILES | sed -e 's/ /'$PATT'/g')
			SQL_FILE_LIST_INPUT=$(echo "('$FILES_IN_LAST_SCAN')")
			echo "$(date):$(basename $0) INFO - File list input $SQL_FILE_LIST_INPUT " >> $DOMAIN_LOG
sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select count(*)|| ':' from  payg_dormancy_req_tracking where batch_filename in $SQL_FILE_LIST_INPUT ;
EOF
			
			echo "SQL output" >> $DOMAIN_LOG
			cat $TEMP_FILE >> $DOMAIN_LOG
			MSISDNS_LOADED_IN_LAST_SCAN="$(cat $TEMP_FILE | cut -f1 -d':')"
			echo "Number of MSISDNs loaded successfully = $MSISDNS_LOADED_IN_LAST_SCAN" >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - MSISDNs successfully loaded in last scan ..$MSISDNS_LOADED_IN_LAST_SCAN" >> $DOMAIN_LOG
			echo >> $REPORT_NAME
sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select count(*)|| ':' from  payg_dormancy_req_tracking where batch_filename in $SQL_FILE_LIST_INPUT and state is null;
EOF

			TOTAL_MSISDN_PENDING="$(cat $TEMP_FILE | cut -f1 -d':')"
			echo "Total number of MSISDNs pending for termination held within Tertio db = $TOTAL_MSISDN_PENDING" >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - Total number of MSISDNs pending for termination held within Tertio db = $TOTAL_MSISDN_PENDIN" >> $DOMAIN_LOG
			echo >> $REPORT_NAME
sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select count(*)|| ':' from  payg_dormancy_req_tracking where batch_filename in $SQL_FILE_LIST_INPUT and state ='Rejected' and substr(result,1,4) in('9007','9008','9009');
EOF

			TOTAL_MSISDN_REJECTED="$(cat $TEMP_FILE | cut -f1 -d':')"
			echo "Number of MSISDNs rejected for loading = $TOTAL_MSISDN_REJECTED" >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - Number of MSISDNs rejected for loading = $TOTAL_MSISDN_REJECTED" >> $DOMAIN_LOG
			echo >> $REPORT_NAME
sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select batch_filename|| ',' || msisdn || ',' || accountid ||','||retirement_reason ||',' || category ||',' || substr(result,7)  from  payg_dormancy_req_tracking where batch_filename in $SQL_FILE_LIST_INPUT and state ='Rejected' and substr(result,1,4) in('9007','9008','9009');
EOF
			cat $TEMP_FILE >> $REPORT_NAME
			echo "$(date):$(basename $0) INFO - MSISDNs rejected for loading " >> $DOMAIN_LOG
			cat $TEMP_FILE	
			echo "$(date):$(basename $0) INFO - Copying $REPORT_NAME to $ARCHIVE_DIR and moving to $OUTPUT_DIR" >> $DOMAIN_LOG
			cp $REPORT_NAME $ARCHIVE_DIR	
			mv $REPORT_NAME $OUTPUT_DIR
		fi
	fi

	echo "$(date):$(basename $0) INFO - Sleep for $SLEEP_DURATION  second " >> $DOMAIN_LOG
	sleep $SLEEP_DURATION
done
