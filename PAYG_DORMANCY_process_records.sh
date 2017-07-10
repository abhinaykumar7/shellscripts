#! /bin/ksh
################################################################################
# This script load input file to db, validate each record  and then create req #
# XML									       #
#                                                                              #
#                                                                              #
################################################################################
#* Usage: PAYG_DORMANCY_process_records.sh                                     *
#*                                                                             *
#* Version    Modified By     Date              Description                    *
#*******************************************************************************
#*  1.0       Abhinay        05-06-2017         Initial Version                *
#*******************************************************************************

# Set up environment

INPUT_DIR=$PAYG_DORMANCY_DOMAIN"/Input"
PROCESSING_DIR=$PAYG_DORMANCY_DOMAIN"/Processing"
ARCHIVE_DIR=$PAYG_DORMANCY_DOMAIN"/Archive"
OUTPUT_DIR=$PAYG_DORMANCY_DOMAIN"/Output"
TERTIO_REPORT_DIR=$PAYG_DORMANCY_DOMAIN"/tertio_report"
ERROR_DIR=$PAYG_DORMANCY_DOMAIN"/Error"
DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"
TEMP_FILE=$PAYG_DORMANCY_DOMAIN"/Processing/temp_req_processor.txt"
TEMP_SQL_FILE_RESULT=$PAYG_DORMANCY_DOMAIN"/Processing/temp_update_result.txt"
TEMP_FILE_STATUS_UPDATE=$PAYG_DORMANCY_DOMAIN"/Processing/temp_update_statis.txt"
LOCK_FILE=$PAYG_DORMANCY_DOMAIN"/domain_lock_rec_processor.sts"
DB_UNAME=$(awk -F= '/^UserName/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_PASSWORD=$(awk -F= '/^Password/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_CONNECT_STRING=$DB_UNAME/$DB_PASSWORD
SQL_UPDATE_FILE=$PROCESSING_DIR"/status_update.sql"
DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

echo "$(date):$(basename $0) - Inside request processor" >> $DOMAIN_LOG
if [ -f $LOCK_FILE ]
then
        # Obviously not starting it using the start script and so echo to stdout
        echo >> $DOMAIN_LOG
	echo "$(date):$(basename $0) - $LOCK_FILE exists, indicating that record processor is already running" >> $DOMAIN_LOG
        echo >> $DOMAIN_LOG
        return 9
fi

echo "$(date):$(basename $0) - Creating $LOCK_FILE" >> $DOMAIN_LOG
# Indicate that the domain is starting by creating a lock file
touch $LOCK_FILE

# Initiate loop - this is an infinite loop whose job is simply to progress batches through
# the state machine.



cd $PROCESSING_DIR
while [ INFINTE ]
do
	DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"
	echo "$(date):$(basename $0) - Request processor is alive..." >> $DOMAIN_LOG
	
	if [ -f $PAYG_DORMANCY_DOMAIN"/STOP_rec_processor" ]
	then
		echo "$(date):$(basename $0) - Request processor shutting down..." >> $DOMAIN_LOG
		rm $LOCK_FILE
		rm $PAYG_DORMANCY_DOMAIN"/STOP_rec_processor"
		return 0
	fi
	echo "$(date):$(basename $0) - Request processor is going to pick request for processing" >> $DOMAIN_LOG

	# Read the threshold value from config parameters

	NUM_REC_TO_PICK=$(awk -F= '/^BATCH_THRESHOLD/ {print $2}' ${PAYG_DORMANCY_DOMAIN}/config_param.file)
	BSO_PRIORITY=$(awk -F= '/^BSO_PRIORITY/ {print $2}' ${PAYG_DORMANCY_DOMAIN}/config_param.file)
	echo "$(date):$(basename $0) - Going to pick $NUM_REC_TO_PICK or less for processing..." >> $DOMAIN_LOG

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select * from ( select rownum||','||batch_filename||','||accountid||','||msisdn from payg_dormancy_req_tracking where state is null order by date_created) where rownum <= '$NUM_REC_TO_PICK' ;
EOF
	> $SQL_UPDATE_FILE

	
	echo "$(date):$(basename $0) INFO - Number of records to process ....." >> $DOMAIN_LOG
	cat $TEMP_FILE | wc -l 

	while read LINEDATA1
	do
		BATCH_FILE=$(echo $LINEDATA1 | cut -f2 -d',')
		ACCOUNTID=$(echo $LINEDATA1 | cut -f3 -d',')
		MSISDN=$(echo $LINEDATA1 | cut -f4 -d',')		
	
			
		#Get the ICCID for MSISDN followed by IMSI attached to ICCID


		echo "$(date):$(basename $0) INFO - Processing $LINEDATA1" >> $DOMAIN_LOG
		echo "$(date):$(basename $0) INFO - Getting ICCID for MSISDN" >> $DOMAIN_LOG

		$PAYG_DORMANCY_DOMAIN/PAYG_DORMANCY_get_iccid.sh $MSISDN

		ICCID=$(cat ICCID.txt)
		echo "$(date):$(basename $0) INFO - ICCID retrieved is ..$ICCID.. for MSISDN" >> $DOMAIN_LOG
		if  [ "$ICCID" = "" ]
		then
			STATUS="Rejected"
			RESULT="9010 - ICCID corresponding to MSISDN not found in NumeriTrack"
			echo "$(date):$(basename $0) INFO - ICCID retrieved is ..$ICCID.. for MSISDN" >> $DOMAIN_LOG
			echo "$(date):$(basename $0) ERROR - ICCID corresponding to MSISDN not found in NumeriTrack" >> $DOMAIN_LOG
		 	echo "update payg_dormancy_req_tracking set state = 'Rejected', result='$RESULT' where BATCH_FILENAME = '$BATCH_FILE' and ACCOUNTID='$ACCOUNTID' and MSISDN ='$MSISDN';" >> $SQL_UPDATE_FILE
		fi

		rm ICCID.txt soapreq1.xml output1.xml > /dev/null


		if [ "$STATUS" != "Rejected" ]
        	then
                	# Get IMSI attached to ICCID

			$PAYG_DORMANCY_DOMAIN/PAYG_DORMANCY_get_imsi.sh $ICCID

			IMSI=$(cat imsi.txt)

			echo "$(date):$(basename $0) INFO - IMSI retrieved is ..$IMSI.. for ICCID..$ICCID..and MSISDN ..$MSISDN.." >> $DOMAIN_LOG
			if  [ "$IMSI" = "" ]
			then
				STATUS="Rejected"
				RESULT="9011 - IMSI corresponding to MSISDN and ICCID not found in NumeriTrack"
				echo "$(date):$(basename $0) ERROR - IMSI corresponding for ICCID and MSISDN not found in NumeriTrack" >> $DOMAIN_LOG
		 		echo "update payg_dormancy_req_tracking set state = 'Rejected', result='$RESULT' where BATCH_FILENAME = '$BATCH' and ACCOUNTID='$ACCOUNTID' and MSISDN ='$MSISDN';" >> $SQL_UPDATE_FILE
			fi

			rm imsi.txt soapreq1.xml output1.xml > /dev/null
		fi

		if [ "$STATUS" != "Rejected" ]
        	then
		#Validate in PeopleSoft

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_SQL_FILE_RESULT
set serveroutput on
set feedback off
declare
        v_status                number;
        v_file_name     varchar2(256);
        v_msisdn                varchar2(12);
        v_accountid     varchar2(10);
        v_imsi          varchar2(15);
begin
        v_file_name := '$BATCH_FILE';
        v_accountid := '$ACCOUNTID';
        v_msisdn := '$MSISDN';
        v_imsi := '$IMSI';
        dbms_output.put_line('invoking db procedure');
        PAYG_DORMANCY_validate_in_psft(v_file_name,v_accountid,v_msisdn,v_imsi,v_status);
        dbms_output.put_line('PSFT_Verification_Status=' || v_status);
END;
/
EOF
	

		echo "$(date):$(basename $0)" >> $DOMAIN_LOG
		echo "$(date):$(basename $0) INFO - Details of PeopleSoft validation " >> $DOMAIN_LOG
		cat $TEMP_SQL_FILE_RESULT >> $DOMAIN_LOG
	
		PSFT_CHECK_STATUS=$(awk -F= '/^PSFT_Verification_Status/ {print $2}' $TEMP_SQL_FILE_RESULT)
		echo "$(date):$(basename $0): Return code from PeopleSoft check :$PSFT_CHECK_STATUS" >> $DOMAIN_LOG
		if [ "$PSFT_CHECK_STATUS" = "0" ]
		then
			echo "$(date):$(basename $0) ERROR - Record ..$LINEDATA1 has been rejcted by PeopleSoft validation" >> $DOMAIN_LOG
		else
			echo "$(date):$(basename $0) INFO - Creating XML for $LINEDATA1" >> $DOMAIN_LOG
			# Create xml and submit it

			BSOID="DORMANCY_"$ACCOUNTID"_"$MSISDN

			BSOPAYLOAD=`cat $PAYG_DORMANCY_DOMAIN"/terminateusim_template"`
			XML_REQ=`echo "$BSOPAYLOAD" | sed "s/~IMSI~/$IMSI/g ; s/~ICCID~/$ICCID/g ; s/~BSOID~/$BSOID/g ; s/~MSISDN~/$MSISDN/g ; s/~ACCOUNTID~/$ACCOUNTID/g"`

			echo "$(date):$(basename $0) INFO - XML Created is as follows" >> $DOMAIN_LOG
			echo "$(date):$(basename $0)" >> $DOMAIN_LOG
			echo $XML_REQ
			echo "$(date):$(basename $0)" >> $DOMAIN_LOG
			echo "$XML_REQ" > teminateusim_request_xml.xml

			# Store request xml and update the STATE to submitted-only SQL file updated
			echo "update payg_dormancy_req_tracking set state = 'Submitted', request_xml = utl_raw.cast_to_raw('$XML_REQ') where BATCH_FILENAME = '$BATCH_FILE' and ACCOUNTID='$ACCOUNTID' and MSISDN ='$MSISDN'; " >> $SQL_UPDATE_FILE

			# Submit XML
			cd $PAYG_DORMANCY_DOMAIN/batchSOproc/source

			tclsh PAYG_DORMANCY_batchSO_submitter.tcl $PAYG_DORMANCY_DOMAIN/Processing/teminateusim_request_xml.xml $BSO_PRIORITY 2> /dev/null
			cd -
			rm teminateusim_request_xml.xml > /dev/null
		fi

	fi
	# Update the status of record in DB for NT validation:

	done < $TEMP_FILE
echo "$(date):$(basename $0):Setting record to Submitted in DB " >> $DOMAIN_LOG
if [ -s $SQL_UPDATE_FILE ]
then
sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE_STATUS_UPDATE
@'$SQL_UPDATE_FILE';
commit;
exit;
EOF
echo "$(date):$(basename $0) Result of SQL update" >> $DOMAIN_LOG
cat $TEMP_FILE_STATUS_UPDATE >> $DOMAIN_LOG
fi

	
# update 
rm $TEMP_FILE $TEMP_SQL_FILE_RESULT $SQL_UPDATE_FILE $TEMP_FILE_STATUS_UPDATE 2> /dev/null
SLEEP_DURATION=$(awk -F= '/^DURATION_SLEEP_RECORD_PROCESSOR/ {print $2}' ${PAYG_DORMANCY_DOMAIN}/config_param.file)

echo "$(date):$(basename $0) " >> $DOMAIN_LOG
echo "$(date):$(basename $0) Finished request processor , will sleep for $SLEEP_DURATION second and pick records for processign afterwards" >> $DOMAIN_LOG
echo "$(date):$(basename $0) " >> $DOMAIN_LOG
sleep $SLEEP_DURATION
done


