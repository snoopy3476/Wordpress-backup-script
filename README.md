# Wordpress Backup
A shell script which creates a full backup of a Wordpress site
## Prepare
  - Set Mysql admin user ID/PW to `$MYSQL_ID` and `$MYSQL_PW` at the top of the script
  - Change the permissions
    - `sudo chown root:root ./wordpress-backup.sh`
    - `sudo chmod 700 ./wordpress-backup.sh`
## Usage
`sudo ./wordpress-backup.sh <wordpress-root-dir> <backup-root-dir> [comments-for-the-backup]`
  - **wordpress-root-dir**: Root directory of the wordpress
  - **backup-root-dir**: Root directory of the backup
  - **comments-for-the-backup**: (Optional) Comments to append to the backup filename
## Job lists of the script
  - **Dump Wordpress DB**: Make a whole dump of wordpress DB (mysql), then put it into the wordpress root dir
  - **Backup Wordpress Data Files**: Archive and compress the wordpress root dir, then put it into the backup root dir
