# Wordpress Backup
A shell script which creates a full backup of a Wordpress site
## Prerequisites (pkgs)
  - mysqldump
  - pv
  - pigz
  - (And maybe other packages which are expected to be included in most of linux distributions)
## Prepare
  - Create a new mysql user account which has admin privilege to backup wordpress data, if does not exist
  - If you want to enter mysql admin ID/PW automatically on each script run,
    - Copy config template to config file: `cp mysql-info.config.template mysql-info.config`
    - Set the mysql admin ID/PW to `$MYSQL_ID` and `$MYSQL_PW` in the config file 'mysql-info.config'
    - Change the permissions
      - `sudo chown 0:0 ./mysql-info.config`
      - `sudo chmod 600 ./mysql-info.config`
## Usage
`sudo ./wordpress-backup.sh <wordpress-root-dir> [comments-for-the-backup]`
  - **wordpress-root-dir**: Root directory of the wordpress
  - **comments-for-the-backup**: (Optional) Comments to append to the backup filename
## Job lists of the script
  - **Dump Wordpress DB**: Make a whole dump of wordpress Mysql DB (.db.mysqldump)
  - **Backup Wordpress Data Files**: Archive and compress the DB dumpfile above & the wordpress root dir
