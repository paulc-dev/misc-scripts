check_backup_task.sh
-This script is a simple example of a custom Nagios check I created that will check the output log of a backup script and determine if the job is running as it should be.

nagios_refresh.sh
- I manage hundreds of AWS EC2 instance, and over time it was becoming problematic to try to manually add/remove instances from the nagios configuration files. This script will use the describle-instances command to generate a list of instances for a given set of filters. Then nagios configuration file for those instances is then built off of that list.
