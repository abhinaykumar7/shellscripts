#!/bin/ksh
#******************************************************************************#
# PAYG_DORMANCY_house_keeping.ksh  
#                                                                              #
#******************************************************************************#
#* Version    Modified By     Date              Description                    #
#******************************************************************************#
#*  1.0       Praveen        07-June-2017       Initial draft                  #
#******************************************************************************#

DB_UNAME=$(awk -F= '/^UserName/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_PASSWORD=$(awk -F= '/^Password/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_CONNECT_STRING=$DB_UNAME/$DB_PASSWORD
HOUSEKEEPING_PERIOD=$(awk -F= '/^HOUSEKEEPING_PERIOD/ {print $2}' ./config_param.file)
DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

echo "$(date):$(basename $0) - Starting the house_keeping script" >> $DOMAIN_LOG;
echo "##########################################################" ;
echo "Starting the PAYG_DORMANCY_house_keeping script" ;
echo "##########################################################" ;

sqlplus -s $DB_CONNECT_STRING << EOF >> $DOMAIN_LOG
        set serveroutput on
        set feedback on
DECLARE 
        cursor records_to_delete is select batchtable.batch_filename from payg_dormancy_batch_tracking BATCHTABLE , payg_dormancy_req_tracking REQUESTTABLE where ( requesttable.state = 'Completed' OR requesttable.state = 'Rejected' )  AND requesttable.completed_on < sysdate-$HOUSEKEEPING_PERIOD AND requesttable.batch_filename = batchtable.batch_filename;
             V_records_to_delete      records_to_delete%ROWTYPE;
             v_sysdate                timestamp;	
             v_batch_filename         payg_dormancy_batch_tracking.batch_filename%type;
             V_number_of_records_deleted number ;
BEGIN

             IF NOT records_to_delete%ISOPEN
             THEN
                  OPEN records_to_delete;
             END IF;

             FETCH records_to_delete INTO V_records_to_delete;
             V_number_of_records_deleted := 0 ;

             WHILE records_to_delete%FOUND
             LOOP

                v_batch_filename := V_records_to_delete.batch_filename ;
                delete from payg_dormancy_batch_tracking where
                       batch_filename = v_batch_filename;
                
                delete from payg_dormancy_req_tracking where 
                       batch_filename = v_batch_filename;

                commit;

                fetch records_to_delete into V_records_to_delete;

                V_number_of_records_deleted := V_number_of_records_deleted + 1 ;

                select to_char(sysdate, 'DD-MON-YYYY HH:MM:SS') into v_sysdate from dual;
                dbms_output.put_line( v_sysdate || ' PAYG_DORMANCY_house_keeping - number of records deleted so far:' || V_number_of_records_deleted);

        end loop;

end;

/
EOF

unset RESULTS

