#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# Version 1.02 April 5th 2021

# Example Execution: sudo bash /home/ubuntu/update_dns.sh
# Reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html

# Usage: sudo bash /home/ubuntu/update_dns.sh
# To run as CRON job every five minutes as root user see https://crontab-generator.org/
# Make script executable
# chmod +x /home/ubuntu/update_dns.sh
# Edit cron file for root user
# sudo crontab -e
# */5 * * * * sudo bash /home/ubuntu/update_dns.sh > /home/ubuntu/update_dns.sh.txt

# Prepare script variables
DNS_ZONE="bsides.dns.splunkstudy.club"
UPDATE_TOKEN="4ztzt3fDWr2Yv1A26P5YWnQV4dGQUO7tN/fVM7QqBd0="
UPDATE_TOKEN_NAME="tsig-227759.dynv6.com"
UPDATE_TOKEN_TYPE="hmac-md5" 
DNS_SERVER="ns1.dynv6.com"
SERVER_INT_ADDR=`curl http://169.254.169.254/latest/meta-data/local-ipv4` || fail
SERVER_EXT_ADDR=`curl http://169.254.169.254/latest/meta-data/public-ipv4` || fail
AWS_INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id` || fail
HOME_PATH="/home/ubuntu/"
DNS_CMD_FILE=$HOME_PATH"nsupdate.txt"
DNS_LOG_FILE=$HOME_PATH"nsupdate_log.txt"

# look up splunk hostname in Splunk config files
SERVER_FILE="/opt/splunk/etc/system/local/server.conf"
FORWARDER_FILE="/opt/splunkforwarder/etc/system/local/server.conf"
if [ -f "$SERVER_FILE" ]; then
    echo "Splunk Server "$FILE" exists."
    SPLUNK_SERVERNAME=`sudo grep serverName /opt/splunk/etc/system/local/server.conf | sed 's/[ ][ ]*//g' | cut -c 12-`
    DNS_A_RECORD_EXT=$SPLUNK_SERVERNAME"-ext."$DNS_ZONE
    DNS_A_RECORD_INT=$SPLUNK_SERVERNAME"-int."$DNS_ZONE
elif [ -f "$FORWARDER_FILE" ]; then
    echo "Splunk Forwarder "$FILE" exists."
    SPLUNK_SERVERNAME=`sudo grep serverName /opt/splunkforwarder/etc/system/local/server.conf | sed 's/[ ][ ]*//g' | cut -c 12-`
    DNS_A_RECORD_EXT=$SPLUNK_SERVERNAME"-ext."$DNS_ZONE
    DNS_A_RECORD_INT=$SPLUNK_SERVERNAME"-int."$DNS_ZONE
else
    echo "Splunk Enterprise of Splunk Universal Forwarder is not installed under /opt/splunk or /opt/splunkforwarder"
    DNS_A_RECORD_EXT=$SERVER_EXT_ADDR"-ext."$DNS_ZONE
    DNS_A_RECORD_INT=$SERVER_INT_ADDR"-int."$DNS_ZONE
fi
NOW=$(date +"%Y-%m-%d %T")
echo "Updating DNS Records for " $DNS_ZONE " on " $DNS_SERVER " at " $NOW
echo "Updating "$DNS_A_RECORD_EXT " to " $SERVER_EXT_ADDR 
echo "Updating "$DNS_A_RECORD_INT " to " $SERVER_INT_ADDR

# Delete old command file if it exists
sudo rm -f $DNS_CMD_FILE || fail

# Append new command file with nsupdate commands
echo "server $DNS_SERVER" >> $DNS_CMD_FILE
echo "zone $DNS_ZONE" >> $DNS_CMD_FILE
echo "update delete $DNS_A_RECORD_EXT A" >> $DNS_CMD_FILE
echo "update add $DNS_A_RECORD_EXT 86400 A $SERVER_EXT_ADDR" >> $DNS_CMD_FILE
echo "update delete $DNS_A_RECORD_INT A" >> $DNS_CMD_FILE
echo "update add $DNS_A_RECORD_INT 86400 A $SERVER_INT_ADDR" >> $DNS_CMD_FILE
echo "key "$UPDATE_TOKEN_TYPE":"$UPDATE_TOKEN_NAME" "$UPDATE_TOKEN >> $DNS_CMD_FILE
echo "send" >> $DNS_CMD_FILE

# Execute nsupdates
nsupdate $DNS_CMD_FILE

# Log nsupdates
EPOCH=`date +%s`
echo "UpdateTime="$EPOCH",AWS_INSTANCE_ID="$AWS_INSTANCE_ID",DNS_SERVER="$DNS_SERVER",DNS_EXT_NAME="$DNS_A_RECORD_EXT",DNS_EXT_IP="$SERVER_EXT_ADDR",DNS_INT_NAME="$DNS_A_RECORD_INT",DNS_INT_IP="$SERVER_INT_ADDR >> $DNS_LOG_FILE