#! /bin/ksh
################################################################################
# This script generates reports of PAYG dormancy                               #
#                                                                              #
#                                                                              #
################################################################################
#* Usage: PAYG_DORMANCY_reports.sh                                             *
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
TEMP_FILE=$PAYG_DORMANCY_DOMAIN"/Processing/temp_report.txt"
DB_UNAME=$(awk -F= '/^UserName/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_PASSWORD=$(awk -F= '/^Password/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_CONNECT_STRING=$DB_UNAME/$DB_PASSWORD
SQL_UPDATE_FILE=$PROCESSING_DIR"/status_update.sql"

DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"
MSISDN_VERIFICATION_REPORT="MSISDNVerificationFailuresReport-$(date "+%Y%m%d")-$(date "+%H%M%S")"
TERTIO_FAILURE_REPORT="TertioFailuresReport-$(date "+%Y%m%d")-$(date "+%H%M%S")"

cd $PROCESSING_DIR

echo "$(date):$(basename $0) INFO - Generating reports, msisdn termination report  " >> $DOMAIN_LOG


sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select count(*) ||':'amsisdn from  payg_dormancy_req_tracking where date_created >= sysdate - 1 and result like '%Success%';
commit;
EOF

NUMBER_OF_SUCCESS_MSISDN=$(cat $TEMP_FILE | cut -f1 -d':')

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select to_char(msisdn) from  payg_dormancy_req_tracking where date_created >= sysdate - 1 and result like '%Success%';
commit;
EOF

MSISDN_TERMINATION_REPORT="TerminatedMSISDNReport-$(date "+%Y%m%d")-$(date "+%H%M%S")"
DATETIME=`date "+%d%m%Y-%H%M%S"` 
echo "$(date):$(basename $0) INFO - Copying $MSISDN_TERMINATION_REPORT to $ARCHIVE_DIR and moving same to $OUTPUT_DIR" >> $DOMAIN_LOG
echo "$DATETIME,$NUMBER_OF_SUCCESS_MSISDN"> $MSISDN_TERMINATION_REPORT
cat $TEMP_FILE >> $MSISDN_TERMINATION_REPORT

cp $MSISDN_TERMINATION_REPORT  $ARCHIVE_DIR
mv $MSISDN_TERMINATION_REPORT $OUTPUT_DIR

echo "$(date):$(basename $0) INFO - Generating reports, msisdn verification report  " >> $DOMAIN_LOG

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select msisdn|| ','  || substr(result,1,4) from  payg_dormancy_req_tracking where date_created >= sysdate -1 and state ='Rejected' and substr(result,1,4) in('9001','9002','9003','9004','9005','9006','9999');
commit;
EOF

cat $TEMP_FILE > $MSISDN_VERIFICATION_REPORT

echo "$(date):$(basename $0) INFO - Copying $MSISDN_VERIFICATION_REPORT to $ARCHIVE_DIR and moving same to $OUTPUT_DIR" >> $DOMAIN_LOG
cp $MSISDN_VERIFICATION_REPORT  $ARCHIVE_DIR
mv $MSISDN_VERIFICATION_REPORT $OUTPUT_DIR

sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
set serveroutput on
set newpage 1
set pagesize 0
set heading off
set echo off
set feedback off
set linesize 500;
select msisdn||','|| soid ||',' || REGEXP_SUBSTR(result,'[^:]+',1,1) from  payg_dormancy_req_tracking where date_created >= sysdate -1 and state in('Completed','ManyTransaction') and result not like '%Success%';
commit;
EOF


cat $TEMP_FILE > $TERTIO_FAILURE_REPORT
mv $TERTIO_FAILURE_REPORT $TERTIO_REPORT_DIR

rm $TEMP_FILE 
