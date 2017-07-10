#! /bin/ksh
################################################################################
# This script load input file to db, validate each record  and then create req #
# XML									       #
#                                                                              #
#                                                                              #
################################################################################
#* Usage: PAYG_DORMANCY_response_collector.sh                                  *
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
TEMP_FILE_STATUS_UPDATE=$PAYG_DORMANCY_DOMAIN"/Processing/temp_update_statis.txt"
LOCK_FILE=$PAYG_DORMANCY_DOMAIN"/domain_lock_rsp_collector.sts"
DB_UNAME=$(awk -F= '/^UserName/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_PASSWORD=$(awk -F= '/^Password/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_CONNECT_STRING=$DB_UNAME/$DB_PASSWORD
SQL_UPDATE_FILE=$PROCESSING_DIR"/status_update.sql"

DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"
echo "$(date):$(basename $0) - Inside response collector" >> $DOMAIN_LOG
if [ -f $LOCK_FILE ]
then
        # Obviously not starting it using the start script and so echo to stdout
        echo >> $DOMAIN_LOG
	echo "$(date):$(basename $0) - $LOCK_FILE exists, indicating that response collector" >> $DOMAIN_LOG
        echo >> $DOMAIN_LOG
        return 9
fi

echo "$(date):$(basename $0) - Creating lock file $LOCK_FILE" >> $DOMAIN_LOG
# Indicate that the domain is starting by creating a lock file
touch $LOCK_FILE

# Initiate loop - this is an infinite loop whose job is simply to progress batches through
# the state machine.



cd $PROCESSING_DIR




while [ INFINTE ]
do

	DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

        echo "$(date):$(basename $0) - Response collector alive..." >> $DOMAIN_LOG

        if [ -f $PAYG_DORMANCY_DOMAIN"/STOP_rsp_collector" ]
        then
                echo "$(date):$(basename $0) - Response collector is shutting down..." >> $DOMAIN_LOG
                rm $LOCK_FILE
                rm $PAYG_DORMANCY_DOMAIN"/STOP_rsp_collector"
                return 0
        fi
        echo "$(date):$(basename $0) - Request collector is going to pick request for processing" >> $DOMAIN_LOG
	
	if [ -f $PAYG_DORMANCY_DOMAIN"/STOP_rsp_collector" ]
	then
		echo "$(date):$(basename $0) - Rsp collector shutting down..." >> $DOMAIN_LOG
		rm $LOCK_FILE
		return 0
	fi

echo "$(date):$(basename $0) - Rsp collector, starting DB procedure..." >> $DOMAIN_LOG
sqlplus -s $DB_CONNECT_STRING << EOF >>  $DOMAIN_LOG
set serveroutput on
set feedback off
begin
dbms_output.put_line('Going to execute payg_dormancy_rsp_collector');
payg_dormancy_rsp_collection;
END;
/
EOF

SLEEP_DURATION=$(awk -F= '/^DURATION_SLEEP_RESPONSE_COLLECTOR/ {print $2}' ${PAYG_DORMANCY_DOMAIN}/config_param.file)
echo "$(date):$(basename $0) " >> $DOMAIN_LOG
echo "$(date):$(basename $0) - Rsp collector, completed will sleep for $DURATION_SLEEP_RESPONSE_COLLECTOR second and starte DB procedure again..." >> $DOMAIN_LOG
echo "$(date):$(basename $0) " >> $DOMAIN_LOG
sleep $SLEEP_DURATION
done
