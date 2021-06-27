#!/bin/bash

#
#   [wordpress-backup.sh]
#       - by snoopy3476@outlook.com
#
#     A backup script which archives both Wordpress DB & Wordpress files.
#
#
#
# - Usage
#
#   $ sudo ./wordpress-backup.sh <wordpress-root> [comments (optional)]
#
#   ex)
#     $ sudo ./wordpress-backup.sh /var/www/html/
#     $ sudo ./wordpress-backup.sh /var/www/html/wordpress-dir "wordpress-v5.7.2"
#
#
#
# - Job list
#
#   1. Stop apache
#   2. Dump Mysql Wordpress DB to .db.mysqldump
#   3. Archive and compress both DB dumpfile (.db.mysqldump) & and Wordpress root directory
#   4. Start apache
#
#
#
# - mysql-info.config
#
#   If you copy 'mysql-info.config.template' to 'mysql-info.config',
#   (with both owner uid/gid to 0 (root) + permission 600)
#   then the ID/PW in the mysql-info.config will be used instead of being prompted on every script run.
#



# config
DB_MYSQLDUMP=.db.mysqldump
ARCHIVE_FILE_BASENAME="wparchive-$(date +'%y%m%d%H%M%S')"
ARCHIVE_FILE_EXT="tar.gz"



# check required binaries
REQ_BIN_LIST="dirname pwd sudo stat chown basename readlink date grep sed systemctl mysqldump tar pv pigz rm"
NOT_EXIST_BIN_LIST=""

for REQ_BIN in $REQ_BIN_LIST
do
	command -v "$REQ_BIN" > /dev/null 2> /dev/null
	if [ $? -ne 0 ]
	then
		NOT_EXIST_BIN_LIST="$NOT_EXIST_BIN_LIST '$REQ_BIN'"
	fi
done

if [ -n "$NOT_EXIST_BIN_LIST" ]
then
	echo "Required binaries do not exist: $NOT_EXIST_BIN_LIST"
	exit 1
fi



# Check config file ownership & permissions
SCRIPTPATH="$( cd -- '$(dirname \"$0\")' >/dev/null 2>&1 ; pwd -P )"

MYSQL_INFO_FILE="$SCRIPTPATH/mysql-info.config"
if [ -f "$MYSQL_INFO_FILE" ]
then

	FILE_PERM=$(stat -c '%u:%g-%a' "$MYSQL_INFO_FILE")
	if [ "$FILE_PERM" != "0:0-400" ] && [ "$FILE_PERM" != "0:0-600" ]
	then
		echo "The permissions of the mysql config file are not set properly!"
		echo "Execute following commands before run the script:"
		echo
		echo "  $ sudo chown 0:0 \"$MYSQL_INFO_FILE\""
		echo "  $ sudo chmod 600 \"$MYSQL_INFO_FILE\""
		echo
		exit 1
	fi

fi



# Root check
if [ "$UID" != "0" ]
then
	echo "Run as root user!"
	exit 1
fi



# Help
if [ "$#" -lt 1 ]
then
	echo "usage: $0 <wordpress-root> [comments]"
	exit 1
fi



# Args process
WP_ROOT=$(readlink -f "$1")
if [ -n "$2" ]
then
	ARCHIVE_FILE_COMMENTS="-[$2]"
fi



# Load wp-config.php define vars
if [ ! -f "$WP_ROOT/wp-config.php" ]
then
	echo "No wp-config.php found in the wordpress-root ($WP_ROOT)!"
	exit 1
fi
eval $(\
	grep "^define" "$WP_ROOT/wp-config.php" | \
	sed -e "s/define\s*(\s*'\([^']*\)'\s*,\s*\('[^']*'\|true\|false\)\s*)\s*;.*/\1=\2/g"\
	)
source "$MYSQL_INFO_FILE" 2> /dev/null # import mysql user info from config file
DB_USER="$MYSQL_ID"
DB_PASSWORD="$MYSQL_PW"



# Stop apache2
echo Stopping apache2...
systemctl stop apache2
RET=$?
if [ $RET -ne 0 ]
then
	systemctl start apache2
	exit $RET
fi



# Dump WP DB
echo Backing up DB...

# check DB id/pw from prompt
if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]
then
	echo
	echo "No DB id/password found in the config file."
	echo
	echo "Set your DB id/password to the variables \$MYSQL_ID and \$MYSQL_PW"
	echo "inside the mysql config file \"$MYSQL_INFO_FILE\""
	echo "if you want to pass them automatically."
	echo
	echo "  Ex)"
	echo "	MYSQL_ID='mysql-admin-account-id'"
	echo "	MYSQL_PW='mysql-admin-account-pw'"
	echo


	# get id from stdin
	echo -n "Mysql admin ID: "
	read DB_USER
	# get pw from stdin, without echo
	echo -n "Mysql password: "
	read -s DB_PASSWORD
	echo

	# recheck id/pw
	if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]
	then
		echo "Mysql ID and password cannot be empty!"
		exit 1
	fi

fi

mysqldump --add-drop-table --single-transaction --routines --triggers --databases \
	"$DB_NAME" -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" > "$DB_MYSQLDUMP"

RET=$?
if [ $RET -ne 0 ]
then
	systemctl start apache2
	exit $RET
fi



# Archive WP DB & Files
echo Backing up WP...

ESTIMATED_SIZE=$(( $(du -sb "$DB_MYSQLDUMP" | cut -f1) + $(du -sb "$WP_ROOT" | cut -f1) ))
if ! [ "$ESTIMATED_SIZE" -gt 0 ] 2> /dev/null
then
	ESTIMATED_SIZE=0
fi

ARCHIVE_FILE="$ARCHIVE_FILE_BASENAME""$ARCHIVE_FILE_COMMENTS"."$ARCHIVE_FILE_EXT"

tar -Pc "$DB_MYSQLDUMP" -C $(dirname "$WP_ROOT") $(basename "$WP_ROOT") | pv -s "$ESTIMATED_SIZE" | pigz > "$ARCHIVE_FILE"

RET=$?
rm -f "$DB_MYSQLDUMP" 2> /dev/null # remove db dump after archive
if [ $RET -ne 0 ]
then
	systemctl start apache2
	exit $RET
fi



# Restart apache2
echo Starting apache2...
systemctl start apache2
RET=$?
if [ $RET -ne 0 ]
then
	exit $RET
fi



# Change owner to the user before sudo
if [ -z "$SUDO_UID" ] || [ -z "$SUDO_GID" ]
then
	exit 1
fi
chown "$SUDO_UID":"$SUDO_GID" "$ARCHIVE_FILE"


echo "The current wordpress archive is stored to the following file:"
echo "   - '$ARCHIVE_FILE'"
echo
echo "DB dump file can be found at the root of the archive ($DB_MYSQLDUMP)"
echo
