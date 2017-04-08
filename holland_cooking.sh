#!/bin./bash

clear; 
## server_number
#echo -e "\nServer Number : " $(cat /root/.rackspace/server_number ) "\n"; 

lines()
{
	for i in $(seq $1)
		do echo -n "="
	done;
}

## Is it a plesk boxA
rpm -q psa 2>&1 > /dev/null

if [[ $? == 1 ]]; then
	echo "Non-Plesk Server"
	plesk="no"
else
	echo "Plesk Server"
	plesk="yes"
	psa_version=$(rpm -q psa)
fi;

echo -e "Checking for Mysql or similar databases..\n"

## Finding OS
if [[ -a /etc/redhat-release ]]; then 
	os=$(for i in $(cat /etc/redhat-release); 
		do echo $i | tr "A-Z" "a-z" | awk '$1~ /^(centos|red|hat|[0-9])/'; 
		done | tr "\n" " " | sed 's/red\ hat/redhat/g');
else 
	os=$(grep -i pretty_name /etc/*-release | cut -d= -f2 | sed 's/\"//g'| awk '{print $1,$2}'| tr "A-Z" "a-z"); 
fi; 

echo -e "\nOS: $os"

## os_short to be used to decide whether to use apt / service / systemctl
# values could be { rhel6, rhel7, ubuntu} **Any version less then rhel/centos6 will show as rhel6 ##
os_short_version=$(if [[ $os == ubuntu* ]]; then echo ubuntu; elif [[ $(echo $os|awk '{print $2}'|cut -d. -f1) -le 6 ]]; then echo rhel6; else echo rhel7; fi;)

## Ubuntu or rhel ?
os_short=$(if [[ $os == ubuntu* ]]; then echo ubuntu; else echo rhel; fi;);  

## Database installed?  if yes what ?
case "$os_short_version" in
	rhel6)
		if [[ -a $(which mysqld) ]]; then 
			db_name=rpm -qf $(which mysqld); 
		else
			db_name=$(rpm -qa| egrep -i 'mysql-server|mysql[0-9][0-9]u?-server|mariadb-server|mariadb[0-9][0-9][0-9]u-server|percona-server-server' | tail -1); 
		fi
		
		if [[ -z $db_name ]];	then 
			echo "I cant find any Databases. You might want to check it manually"
		fi ;;

	rhel7)
		db_name=$(rpm -qa| egrep -i 'mysql|mariadb|percona' | grep -i server)
		if [[ -z $db_name ]]; then 
			echo "I cant find any Databases. You might want to check it manually"
		fi ;;

	ubuntu)
		echo "I dont support Ubuntu yet."	
		exit 1 ;;
	*)
		echo "Unsupported Operating System"
		exit 1 ;;
esac


# if db_installed, then is db_running ?
if [[ ! -z $db_name ]] && [[ $os_short_version == "rhel6" ]]; then 
	db_init=$(rpm -ql $db_name | grep -i "init\.d" | awk -F "/" '{print $(NF-0)}')

	## db_running ?
	service $db_init status > /dev/null
	if [[ $? == 0 ]]; then 
		db_running="yes"
	else
		db_running="no"
	fi

	## db_enabled ?
	if [[ $(chkconfig --list mysqld | awk '{print $5}' | cut -d: -f2) == "on" ]]
		then 
			db_enabled="yes"
		else
			db_enabled="no"
	fi

	if [[ $db_running == "yes" ]] && [[ $db_enabled == "yes" ]]; then 
		echo -e "\nMysql server: $db_name"
		echo -e "------------> is installed and running and Enabled\n"
		chkconfig --list $db_init
	elif [[ $db_running == "yes" ]] && [[ $db_enabled == "no" ]]; then
		echo -e "\nMysql server: $db_name"
		echo -e "------------> is installed and running BUT NOT ENABLED."
		echo -e "You might want to enable it\n"
		chkconfig --list $db_init
		echo -e "\n\n"
	elif [[ $db_running == "no" ]] && [[ $db_enabled == "yes" ]]; then
		echo -e "\nMysql server: $db_name"
		echo -e "Mysql is installed and enabled BUT NOT RUNNING.\n"
		echo -e "You might want to start it\n"
		service $db_init status
		echo -e "\n\n"
	elif [[ $db_running == "no" ]] && [[ $db_enabled == "no" ]]; then
		echo -e "\nMysql is installed BUT it is NEITHER enabled NOR running."
		echo -e "Probably this server is not used for databases\n"
		chkconfig --list $db_init
		service $db_init status
		echo -e "\n\n"
	fi
				
elif [[ ! -z $db_name ]] && [[ $os_short_version == "rhel7" ]]; then
        db_init=$(rpm -ql $db_name | grep -i service$ | grep -v "@"| awk -F '/' '{print $(NF-0)}')
	
	## db_running ?
	systemctl status $db_init > /dev/null
        if [[ $? == 0 ]]; then 
		db_running="yes"
	else 
		db_running="no"
	fi

	## db_enabled :
	if [[ $(systemctl is-enabled $db_init) == "enabled" ]]; then 
		db_enabled="yes"
	else
		db_enabled="no"
	fi

	if [[ $db_running == "yes" ]] && [[ $db_enabled == "yes" ]]; then 
		echo "\nMysql server: $db_name"
		echo -e "------------> is installed and running and Enabled\n"
	elif [[ $db_running == "yes" ]] && [[ $db_enabled == "no" ]]; then
		echo -e "\nMysql server: $db_name"
		echo -e "------------> is installed and running BUT NOT ENABLED."
		echo -e "You might want to enable it\n"

	elif [[ $db_running == "no" ]] && [[ $db_enabled == "yes" ]]; then
		echo "\nMysql server: $db_name"
		echo -e "------------>  is installed and enabled BUT NOT RUNNING."
		echo -e "You might want to start it\n"
		systemctl status $db_init 
		echo -e "\n\n"

	elif [[ $db_running == "no" ]] && [[ $db_enabled == "no" ]]; then
		echo -e "\nMysql server: $db_name"
		echo -e "Mysql is installed BUT it is NEITHER enabled NOR running."
		echo -e "Probably this server is not used for databases\n"
		systemctl status $db_init
		echo -e "\n\n"
	fi
fi	

	
if [[ $db_running == "yes" ]]; 	then 	
	
	## Db instance parameters
	tf=`mktemp`; for i in $(ps auxf | grep mysqld | grep -vE 'grep|safe'); do echo $i; done | grep "^--"| grep "="| sed -e 's/--//g; s/=/\t/g'| column -t > $tf
	datadir=$(grep datadir $tf| awk '{print $2}'); 
	echo -e "\nMysql is running with :"
	lines 20; echo
	cat $tf
	echo -e "\n"

	## DB Accessible ??
	echo -e "\nMySQL configuration : ";  
	lines 20; echo	
		
	echo; 
	mysqladmin stat &> /dev/null; 
		
	if [ $? == "1" ]; then 
		echo "ERROR    Cant connect to mysql;"; 
		mysqladmin stat; 
	else 
		echo -e "Mysql Uptime  \t ==> \t" `mysqladmin stat | awk '{print $2/60/60, "Hours"}' ` "\n"; 
		mysql -Nse "show variables like 'max_connections'; show status like 'max_used%'"| awk '{print $1,"\t--\t",$2}' | column -t
	fi;

	## Db_logfile		
	mysql_log=$(mysql -Nse "show variables like 'log_error'" | awk '{print $2}')
	echo -e "\n\nLog file : $mysql_log\n\nRecent Errors from logs :"; 
	lines 26; 	
	echo;
		
	### Errors from db_logs
	db_errors=`mktemp`
	timeout 5 grep -i error $mysql_log | grep $(date +%y%m%d) | tail -20 > $db_errors
	if [[ ! -s $start_shut  ]]; then
		echo "None"
	else
		cat $db_errors
	fi
				
	echo -e "\n\n(If any) Mysql Stop/starts today :" ; 
	lines 35
	echo; 

	### Finding db starts / shutdowns
	start_shut=`mktemp`; 
	timeout 5 egrep 'starting shutdown|ready for connections' -i $mysql_log | grep $(date +%y%m%d) > $start_shut ; 
		
	if [[ ! -s $start_shut ]]; then 
		echo "None."; 
	else 
		cat $start_shut | tail -20; 
	fi; 
		
	rm -rf $start_shut;  
fi; 

##### Checking Holland now 
echo -e "\n\n"
lines 20; echo
echo -e "Checking Holland..";  
lines 20; 
echo -e "\n\n"

## If Holland Instaled 

if rpm -qa | grep -i "holland-1." ; 
	then 
		holl_log="/var/log/holland"; 
		dir=$(grep -i directory /etc/holland/holland.conf | grep -v ^# | awk '{print $(NF-0)}'); 
		echo -e "\nBackup Dir = $dir\n\nBackup Directory Space:"; 
		df -hP $dir; 
		backupset=$(grep -i ^backupsets /etc/holland/holland.conf   | awk '{print $3}'); 
		echo -e "\nHolland Backupset :" $backupset; 
		estimate=$(grep -i estimate /etc/holland/backupsets/$backupset.conf | grep -v ^#); 
		data_dir=$(grep -i datadir  /etc/my.cnf | grep -v ^#| awk -F "=" '{print $(NF-0)}')
		echo -e "\nMysql Datadir :";
		du -hs $data_dir 
		last_log=$(ls -1tr $(for j in $(for i in `ls -1t /var/log/holland/*`; do file -s $i ; done | grep -v empty |  awk -F ":" '{print $1}'); do echo "$j" `zcat $j | wc -l`; done | awk '$2 > 10' | awk '{print $1}') | tail -1)
file -s $last_log | grep gzip > /dev/null;
	if [ $? == 0 ];	then 
		last_log_gzip=yes; 
	fi; 
		

	### If main logfile is empty.. look for .gz files
	if [ -s $holl_log/holland.log ]; then 
		log="$holl_log/holland.log"; 
		echo $estimate; last_bkup=`mktemp`; 
		zgrep -iE 'final|Backup completed' $holl_log/*.gz  > $last_bkup; 
		grep -iE 'final|backup completed in' $holl_log/holland.log >> $last_bkup; 
		backup_size=$(grep -i final $last_bkup  | tail -1 | awk '{print $(NF-0)}'); 
		echo -e "\nLast backup size is ---\t $backup_size"; 
		echo -n "Last successfull backup : "; 
		complete=$(grep -i "completed in" $last_bkup | tail -1) ; 
		echo $complete | awk '{print $1}' | cut -d ":" -f2; 
		echo -en "\nLast backup duration :\n\t" $(echo $complete | awk '{print $4,$5,$6,$7,$8}') "\n"; 
		rm -rf $last_bkup; 
		echo -e "\n\nFrom backup directory"; 
		ls -ld $dir/$backupset/newest/backup*; 
		echo ; awk '{print $1}' $log | uniq | tail -2 > d; 
		
		for j in `cat d` ; do 
			echo -e "\n$j\n"; 
			grep $j $log | egrep -i 'error|warning|complete|estimated|final'; 
			echo ""; 
		done;  
				
		rm -rf d; 
	elif [[ -s $last_log  && $last_log_gzip == yes ]]; then 
		log=$last_log;
		echo $estimate; 
		backup_size=`zgrep -i final $log | tail -1 | awk '{print $(NF-0)}'`;
		echo -e "\nLast backup size is $backup_size"; 
		echo ""; 
		zcat $log | awk '{print $1}' | uniq | tail -2 > d; 
					
		for j in `cat d` ; do 
			echo -e "\n$j\n"; 
			zgrep $j $log | egrep -i 'error|warning|complete|estimated|final'; 
			echo;
		done; 
		rm -rf  d;
	fi 

elif rpm -qa | grep mysqlbackup ; then 
	echo -e "\nmysqlbackup installed. Check logs manually";  

elif ps auxf | grep mysql | egrep -v 'safe|grep'; then 
	echo -e "\nNeither Holland Nor Mysqlbackup is installed but mysql is running.";  

else 
	echo -e "\nNeither Holland Nor Mysqlbackup is installed. However mysql is also not running."; 
fi;

rm -rf $tf
