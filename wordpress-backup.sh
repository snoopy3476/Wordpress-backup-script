#!/bin/bash

######## MYSQL ADMIN ID/PW - FILL TO MAKE THE SCRIPT WORK ########
MYSQL_ID=''
MYSQL_PW=''
##################################################################



FILE_PERM=$(stat -c '%u:%g-%a' "$0")
if [ "$FILE_PERM" != "0:0-700" ] && [ "$FILE_PERM" != "0:0-500" ]
then
    echo "The permissions of the script file are not set properly!"
    echo "Execute following commands before run the scripts:"
    echo
    echo "  $ sudo chown 0:0 \"$0\""
    echo "  $ sudo chmod 700 \"$0\""
    echo
    exit 1
fi


if [ $# -lt 2 ]
then
    echo "usage: $(basename $0) <wordpress-root> <backup-root> [comments]"
    exit 1
fi

if [ 'root' != $(whoami) ]
then
    echo 'Run as root user!'
    exit 1
fi

if ! [ -z $3 ]
then
    COMMENTS="-[$3]"
fi


WP_ROOT=$(readlink -f "$1")
BACKUP_ROOT=$(readlink -f "$2")
BACKUP_SAVE_NAME="$(date +'%y%m%d-%H%M%S')""$COMMENTS"
BACKUP_FILE="$BACKUP_ROOT"/"$BACKUP_SAVE_NAME".tar.gz
DB_MYSQLDUMP=.db.mysqldump
# Load wp-config.php define vars
eval `grep ^define "$WP_ROOT"/wp-config.php | sed -e "s/define\s*(\s*'\([^']*\)'\s*,\s*\('[^']*'\|true\|false\)\s*)\s*;.*/\1=\2/g"`



# DB Admin User: This should not be empty
DB_USER=$MYSQL_ID
DB_PASSWORD=$MYSQL_PW

if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]
then
    echo 'Fill your DB id and password to the variables $MYSQL_ID and $MYSQL_PW'
    echo 'before you execute this script!'
    exit 1
fi




echo Stopping apache2...
service apache2 stop
RET=$?
if [ $RET -ne 0 ]
then
    exit $RET
fi

echo Backing up DB...
mysqldump --add-drop-table --single-transaction --routines --triggers --databases "$DB_NAME" -h "$DB_HOST" -u "$DB_USER" -p$DB_PASSWORD > "$WP_ROOT/$DB_MYSQLDUMP"

RET=$?
if [ $RET -ne 0 ]
then
    exit $RET
fi

echo Backing up WP...
tar -Pc "$WP_ROOT" | pigz > "$BACKUP_FILE";
RET=$?
if [ $RET -ne 0 ]
then
    exit $RET
fi

rm -f "$WP_ROOT/$DB_MYSQLDUMP" 2> /dev/null


echo Starting apache2...
service apache2 start
RET=$?
if [ $RET -ne 0 ]
then
    exit $RET
fi



id $USER > /dev/null 2> /dev/null
RET=$?
if [ $RET -ne 0 ]
then
    exit $RET
fi
#chown -R $USER.$USER "$BACKUP_SAVE_PATH"

