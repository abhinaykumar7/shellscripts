#! /bin/ksh
################################################################################
# This script load input file to db, validate each record  and then create req #
# XML									       #
#                                                                              #
#                                                                              #
################################################################################
#* Usage: PAYG_DORMANCY_load_validate.sh                                       *
#*                                                                             *
#* Version    Modified By     Date              Description                    *
#*******************************************************************************
#*  1.0       Abhinay        03-06-2017         Initial Version                *
#*******************************************************************************

# Set up environment

INPUT_DIR=$PAYG_DORMANCY_DOMAIN"/Input"
PROCESSING_DIR=$PAYG_DORMANCY_DOMAIN"/Processing"
ARCHIVE_DIR=$PAYG_DORMANCY_DOMAIN"/Archive"
OUTPUT_DIR=$PAYG_DORMANCY_DOMAIN"/Output"
TERTIO_REPORT_DIR=$PAYG_DORMANCY_DOMAIN"/tertio_report"
ERROR_DIR=$PAYG_DORMANCY_DOMAIN"/Error"
TEMP_FILE=$PAYG_DORMANCY_DOMAIN"/Processing/temp.txt"

DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

echo "$(date):$(basename $0) INFO - In batch loader and validator" >> $DOMAIN_LOG

if [ $# -ne 1 ]
then
        echo "$(date):$(basename $0) ERROR - No batch file specified" >> $DOMAIN_LOG

        return 1
fi

cd $PROCESSING_DIR
SOURCE_FILE=$1
cd $INPUT_DIR

if [ ! -f $SOURCE_FILE ]
then
        echo "$(date):$(basename $0) ERROR - Input file $SOURCE_FILE, does not exist" >> $DOMAIN_LOG
        echo "$(date):$(basename $0) ERROR - Exiting." >> $DOMAIN_LOG
	exit
fi

mv  $SOURCE_FILE $PROCESSING_DIR
cd $PROCESSING_DIR

SQL_UPDATE_FILE=$PROCESSING_DIR"/status_update.sql"
> $SQL_UPDATE_FILE

# Create an entry in DB for batch file
NUM_REC=$(cat $SOURCE_FILE | wc -l)

# Load file details to DB
DB_UNAME=$(awk -F= '/^UserName/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_PASSWORD=$(awk -F= '/^Password/ {print $2}' ${PROVHOME}/conf/dbAccess.cfg)
DB_CONNECT_STRING=$DB_UNAME/$DB_PASSWORD
sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
insert into payg_dormancy_batch_tracking values('$SOURCE_FILE','$NUM_REC',sysdate);
commit;
EOF

RETURN_STATUS=$(cat $TEMP_FILE | grep -i error | wc -l)

if [ "$RETURN_STATUS" != "0" ]
then
        echo "$(date):$(basename $0) ERROR - While inserting batch into database,exiting." >> $DOMAIN_LOG
        echo "$(date):$(basename $0) ERROR - Message from Oracle" >> $DOMAIN_LOG
	cat $TEMP_FILE >> $DOMAIN_LOG
	rm $TEMP_FILE
	mv  $SOURCE_FILE $ERROR_DIR
        return 1
fi

ERROR_FILE=$ERROR_DIR"/"$SOURCE_FILE".errorfile"
> $ERROR_FILE
cp $SOURCE_FILE $PAYG_DORMANCY_DOMAIN"/Archive"



echo "$(date):$(basename $0) INFO - Checking if there are any empty values in 3rd field." >> $DOMAIN_LOG

awk -F "," 'length($3) == 0' $SOURCE_FILE >  $SOURCE_FILE"_null_thirdfield.txt"

if [ -s $SOURCE_FILE"_null_thirdfield.txt" ]
then
	echo "$(date):$(basename $0) INFO - There are records which retirement reason as null." >> $DOMAIN_LOG
	while read LINEDATA1
	do
		echo "$LINEDATA1-retirement reason is null" >> $ERROR_FILE
	done < $SOURCE_FILE"_null_thirdfield.txt"

	# Taking out the records which failed to load from source file
	diff $SOURCE_FILE $SOURCE_FILE"_null_thirdfield.txt" | grep ^'<' | sed 's/^.\{,2\}//' > $TEMP_FILE
	mv $TEMP_FILE $SOURCE_FILE
	rm $SOURCE_FILE"_null_thirdfield.txt" > /dev/null	
else
	rm $SOURCE_FILE"_null_thirdfield.txt" > /dev/null	

fi

echo "$(date):$(basename $0) INFO - Checking if there are any empty values in 4th field." >> $DOMAIN_LOG

awk -F "," 'length($4) == 0' $SOURCE_FILE >  $SOURCE_FILE"_null_fourthfield.txt"

if [ -s $SOURCE_FILE"_null_fourthfield.txt" ]
then
	echo "$(date):$(basename $0) INFO - There are records which retirement category as null." >> $DOMAIN_LOG
	while read LINEDATA1
	do
		echo "$LINEDATA1-retirement category is null" >> $ERROR_FILE
	done < $SOURCE_FILE"_null_fourthfield.txt"

	# Taking out the records which failed to load from source file
	diff $SOURCE_FILE $SOURCE_FILE"_null_fourthfield.txt" | grep ^'<' | sed 's/^.\{,2\}//' > $TEMP_FILE
	mv $TEMP_FILE $SOURCE_FILE
	rm $SOURCE_FILE"_null_fourthfield.txt" > /dev/null	
else
	rm $SOURCE_FILE"_null_fourthfield.txt" > /dev/null	

fi

echo "$(date):$(basename $0) INFO - Checking if there are any records record which have accountid length not equal to 10." >> $DOMAIN_LOG
#Check length of account id is 10 digits
awk -F"," '$1 !~ /^[0-9]+$/ || length($1) != 10 {print $ALL}' $SOURCE_FILE > $SOURCE_FILE"_inv_acctid.txt"



if [ -s $SOURCE_FILE"_inv_acctid.txt" ]
then
	echo "$(date):$(basename $0) INFO - There are records which have accountid length not equal to 10." >> $DOMAIN_LOG
	while read LINEDATA1
	do
		ACCOUNTID=$(echo $LINEDATA1 | cut -f1 -d',')
		MSISDN=$(echo $LINEDATA1 | cut -f2 -d',')
		RETIREMENT_REASON=$(echo $LINEDATA1 | cut -f3 -d',')
		CATEGORY=$(echo $LINEDATA1 | cut -f4 -d',')

		if [ ! -z "${ACCOUNTID##*[!0-9]*}" ]
		then
			echo "insert into payg_dormancy_req_tracking(batch_filename,accountid,msisdn,retirement_reason,category,date_created,state,result) values('$SOURCE_FILE','$ACCOUNTID','$MSISDN','$RETIREMENT_REASON','$CATEGORY',sysdate,'Rejected', '9007 - ACCOUNTID length not 10');" >> $SQL_UPDATE_FILE
		
		else
			echo "$LINEDATA1-non numerical accountid OR does not have length of 10" >> $ERROR_FILE
		fi
	done < $SOURCE_FILE"_inv_acctid.txt"

	# Taking out the records which failed to load from source file
	diff $SOURCE_FILE $SOURCE_FILE"_inv_acctid.txt" | grep ^'<' | sed 's/^.\{,2\}//' > $TEMP_FILE
	mv $TEMP_FILE $SOURCE_FILE
	rm $SOURCE_FILE"_inv_acctid.txt" > /dev/null	
else
	rm $SOURCE_FILE"_inv_acctid.txt" > /dev/null	
fi
echo "Debug : Content of SQL update file after checking account id length" >> $DOMAIN_LOG
cat $SQL_UPDATE_FILE >> $DOMAIN_LOG

#Check MSISDN start with 44
MSISDN_PREFIX="44"

grep -v -E "([^,]+,($MSISDN_PREFIX)[0-9]+,[^,]+,[^,]+)" $SOURCE_FILE > $SOURCE_FILE"_invf_msisdn.txt"

if [ -s $SOURCE_FILE"_invf_msisdn.txt" ]
then
	echo "$(date):$(basename $0) INFO - There are records where MSISDN does not start with 44" >> $DOMAIN_LOG
	while read LINEDATA1
	do
		ACCOUNTID=$(echo $LINEDATA1 | cut -f1 -d',')
		MSISDN=$(echo $LINEDATA1 | cut -f2 -d',')
		RETIREMENT_REASON=$(echo $LINEDATA1 | cut -f3 -d',')
		CATEGORY=$(echo $LINEDATA1 | cut -f4 -d',')

		if [ ! -z "${MSISDN##*[!0-9]*}" ]
		then
			echo "insert into payg_dormancy_req_tracking(batch_filename,accountid,msisdn,retirement_reason,category,date_created,state,result) values('$SOURCE_FILE','$ACCOUNTID','$MSISDN','$RETIREMENT_REASON','$CATEGORY',sysdate,'Rejected', '9008 - MSISDN does not start with 44');" >> $SQL_UPDATE_FILE
		else
			echo "$LINEDATA1-non numerical msisdn OR MSISDN does not start with 44" >> $ERROR_FILE
		fi
	done < $SOURCE_FILE"_invf_msisdn.txt"

	# Taking out the records which failed to load from source file
	diff $SOURCE_FILE $SOURCE_FILE"_invf_msisdn.txt" | grep ^'<' | sed 's/^.\{,2\}//' > $TEMP_FILE
	mv $TEMP_FILE $SOURCE_FILE
	rm $SOURCE_FILE"_invf_msisdn.txt" > /dev/null

else
	rm  $SOURCE_FILE"_invf_msisdn.txt" > /dev/null
fi
echo "Debug : Content of SQL update file after checking msidn starts with 44" >> $DOMAIN_LOG
cat $SQL_UPDATE_FILE >> $DOMAIN_LOG

#Check length of msisdn is 12 digits
echo "$(date):$(basename $0) INFO - Checking if there are any records record which have msisdn length not equal to 12." >> $DOMAIN_LOG
awk -F"," '$2 !~ /^[0-9]+$/ || length($2) != 12 {print $ALL}' $SOURCE_FILE > $SOURCE_FILE"_inv_msisdn.txt"

if [ -s $SOURCE_FILE"_inv_msisdn.txt" ]
then
	echo "$(date):$(basename $0) INFO - There are records which have msisdn length not equal to 12." >> $DOMAIN_LOG
	while read LINEDATA1
	do
		ACCOUNTID=$(echo $LINEDATA1 | cut -f1 -d',')
		MSISDN=$(echo $LINEDATA1 | cut -f2 -d',')
		RETIREMENT_REASON=$(echo $LINEDATA1 | cut -f3 -d',')
		CATEGORY=$(echo $LINEDATA1 | cut -f4 -d',')

		if [ ! -z "${MSISDN##*[!0-9]*}" ]
		then
			echo "insert into payg_dormancy_req_tracking(batch_filename,accountid,msisdn,retirement_reason,category,date_created,state,result) values('$SOURCE_FILE','$ACCOUNTID','$MSISDN','$RETIREMENT_REASON','$CATEGORY',sysdate,'Rejected', '9009 - MSISDN length not 12');" >> $SQL_UPDATE_FILE
		else
			echo "$LINEDATA1-non numerical msisdn OR MSISDN length is not 12" >> $ERROR_FILE
		fi
	done < $SOURCE_FILE"_inv_msisdn.txt"

	# Taking out the records which failed to load from source file
	diff $SOURCE_FILE $SOURCE_FILE"_inv_msisdn.txt" | grep ^'<' | sed 's/^.\{,2\}//' > $TEMP_FILE
	mv $TEMP_FILE $SOURCE_FILE
	rm  $SOURCE_FILE"_inv_msisdn.txt" > /dev/null
else
	rm  $SOURCE_FILE"_inv_msisdn.txt" > /dev/null
fi

echo "Debug : Content of SQL update file after checking msidn length is 12" >> $DOMAIN_LOG
cat $SQL_UPDATE_FILE >> $DOMAIN_LOG

if [ -s $SQL_UPDATE_FILE ]
then

	echo "$(date):$(basename $0) INFO - Going to update, error record in DB " >> $DOMAIN_LOG
sqlplus -s $DB_CONNECT_STRING << EOF > $TEMP_FILE
@'$SQL_UPDATE_FILE';
commit;
exit;
EOF
echo "$(date):$(basename $0) INFO - Output from execution of SQL file on DB" >> $DOMAIN_LOG
echo >> $DOMAIN_LOG
echo >> $DOMAIN_LOG
cat $TEMP_FILE >> $DOMAIN_LOG
echo >> $DOMAIN_LOG
echo >> $DOMAIN_LOG
fi


if [ -s $SOURCE_FILE ]
then
	BAD_UPLOAD_FILE=$SOURCE_FILE".bad"
	if [ -f $BAD_UPLOAD_FILE ]
	then
        	rm $BAD_UPLOAD_FILE 2> /dev/null
	fi

	sed -e s/REPLACE/$SOURCE_FILE/ $PAYG_DORMANCY_DOMAIN"/load_control_fileload_control_file.ctl" > final_load_control_fileload_control_file.ctl

	echo "$(date):$(basename $0) INFO - Going to uploading $SOURCE_FILE to DB using SQL Loader, starting sql loader procedure." >> $DOMAIN_LOG
	sqlldr userid=$DB_CONNECT_STRING data=$SOURCE_FILE control=final_load_control_fileload_control_file.ctl log=$PAYG_DORMANCY_DOMAIN"/log/load_"$SOURCE_FILE bad=$BAD_UPLOAD_FILE
	echo "$(date):$(basename $0) INFO - Finished uploading $SOURCE_FILE to DB using SQL Loader." >> $DOMAIN_LOG


	if [  -f $BAD_UPLOAD_FILE ]
	then
        	echo "$(date):$(basename $0) INFO - There are records which fail to load,system would exclude such record from ." >> $DOMAIN_LOG
        	echo "$(date):$(basename $0) INFO - further processing." >> $DOMAIN_LOG
        	echo "$(date):$(basename $0) INFO - Following records have failed to load." >> $DOMAIN_LOG
		echo >> $DOMAIN_LOG
		cat $BAD_UPLOAD_FILE >> $DOMAIN_LOG
		echo >> $DOMAIN_LOG

		# Taking out the records which failed to load from source file
		diff $SOURCE_FILE $BAD_UPLOAD_FILE | grep ^'<' | sed 's/^.\{,2\}//' > $TEMP_FILE
		mv $TEMP_FILE $SOURCE_FILE
		mv $BAD_UPLOAD_FILE $ERROR_DIR
	fi
fi
rm $SOURCE_FILE > /dev/null
rm $SQL_UPDATE_FILE 2> /dev/null
rm $TEMP_FILE 2> /dev/null
rm $SQL_UPDATE_FILE $TEMP_FILE final_load_control_fileload_control_file.ctl 2> /dev/null
