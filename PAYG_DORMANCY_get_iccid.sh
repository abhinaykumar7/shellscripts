# !/bin/ksh
################################################################################
# Start script for the PAYG Dormancy domain.                                   #
#                                                                              #
# This script returns ICCID for input MSISDN                                   #
################################################################################
#* Usage: PAYG_DORMANCY_get_iccid.sh <msisdn>                                  *
#*                                                                             *
#* Version    Modified By     Date              Description                    *
#*******************************************************************************
#*  1.0       Abhinay        25-05-2017         Initial Version                *
#*******************************************************************************

# Set up environment

DOMAIN_LOG=$PAYG_DORMANCY_DOMAIN"/log/PAYG_DORMANCY_domain_"$(date "+%d%m%Y")".log"

if [ $# -ne 1 ]
then
        echo "$(date):$(basename $0) ERROR - No batch file specified" >> $DOMAIN_LOG

        return 1
fi

NT_URL=$(awk -F= '/^NT_URL/ {print $2}' ${PAYG_DORMANCY_DOMAIN}/config_param.file)
NT_USER=$(awk -F= '/^NTUSER/ {print $2}' ${PAYG_DORMANCY_DOMAIN}/config_param.file)

MSISDN=$1

FILE="<?xml version=\""1.0"\" encoding=\""UTF-8"\"?>

<SOAP-ENV:Envelope xmlns:SOAP-ENV=\""http://schemas.xmlsoap.org/soap/envelope/"\">

<SOAP-ENV:Body>

<ns0:NTService.QueryDN xmlns:ns0=\""http://www.evolving.com/NumeriTrack/xsd"\">

<msgId xmlns=\"""\">

<userId xmlns=\"""\">$NT_USER</userId>

</msgId>
<startingDn xmlns=\"""\">$MSISDN</startingDn>

<endingDn xmlns=\"""\">$MSISDN</endingDn>

<quantity xmlns=\"""\">1</quantity>

<resourceState xmlns=\"""\">NoState</resourceState>

<retUserData xmlns=\"""\">0</retUserData>

<multiUserDataOperand xmlns=\"""\">NoMultiUD</multiUserDataOperand>

<retAssocResources xmlns=\"""\">1</retAssocResources>


<retMiscData xmlns=\"""\">1</retMiscData>

</ns0:NTService.QueryDN>

</SOAP-ENV:Body>

</SOAP-ENV:Envelope>"

echo "$FILE" > soapreq1.xml
curl -H "Content-Type: text/xml; charset=utf-8" -H "SOAPAction:query" -d@soapreq1.xml  $NT_URL  > output1.xml

ICCID=`xmllint --shell output1.xml <<< "cat //iccidList/item/text()" | grep -v "^/ >"`

echo>> $DOMAIN_LOG
echo "$(date):$(basename $0) INFO - Output from NT query for ICCID attached to MSISDN $1" >> $DOMAIN_LOG
echo>> $DOMAIN_LOG
cat output1.xml >> $DOMAIN_LOG 
echo >> $DOMAIN_LOG
#echo "$(date):$(basename $0) INFO - ICCID returned from NT is ICCID...$ICCID" >> $DOMAIN_LOG
echo >> $DOMAIN_LOG
echo "$ICCID" > ICCID.txt
