clear; 
## server_number
echo -e "\nServer Number : " $(cat /root/.rackspace/server_number ) "\n"; 

## Finding OS
if [[ -a /etc/redhat-release ]]; 
	then 
		os=$(for i in $(cat /etc/redhat-release); 
			do echo $i | tr "A-Z" "a-z" | awk '$1~ /^(centos|red|hat|[0-9])/'; 
			done | tr "\n" " " | sed 's/red\ hat/redhat/g');
	else 
		os=$(grep -i pretty_name /etc/*-release | cut -d= -f2 | sed 's/\"//g'| awk '{print $1,$2}'| tr "A-Z" "a-z"); fi; 

echo "OS: $os"

## os_short to be used to decide whether to use apt / service / systemctl
# values could be { rhel6, rhel7, ubuntu} **Any version less then rhel/centos6 will show as rhel6 ##
os_short_version=$(if [[ $os == ubuntu* ]]; then echo ubuntu; elif [[ $(echo $os|awk '{print $2}'|cut -d. -f1) -le 6 ]]; then echo rhel6; else echo rhel7; fi;)

## Ubuntu or rhel ?
os_short=$(if [[ $os == ubuntu* ]]; then echo ubuntu; else echo rhel; fi;);  


## Discover Database

case "$os_short" in
	rhel)
		db_temp=$(rpm -qa| egrep -i 'mysql-server|mysql[0-9][0-9]u?-server|mariadb-server|mariadb[0-9][0-9][0-9]u-server|percona-server-server ' | tail -1)
		;;
	ubuntu)
		echo "I dont support Ubuntu yet."	
		exit 1
		;;
esac


if `ps auxf | grep mysqld | grep -v grep > /dev/null `
	then mysql_status="running"
	else mysql_status="not_running"
fi
	
if [[ $mysqld_status == "running" ]]
	then 
		pkg=$(rpm -qf $(ps auxf | grep mysqld | grep -vE 'grep|safe' | awk '{print $12}') | tail -1); 
		echo -e "\n\n$pkg \n------ is installed and running"; 
		setto=$(chkconfig --list $(rpm -ql $pkg | grep init.d | awk -F "/" '{print $(NF-0)}')); 
		setto_st=$(echo $setto | awk '{print $5}' |cut -d ":" -f2); 
		
		if [ $setto_st == "on" ]; 
			then 
				echo -e "\nAnd is set to on"; 
			else 
				ehco "\nAnd is not set to on"; 
		fi; 
		
		echo $setto | column -t; 
		echo -e "\nMySQL configuration : ";  
		
		for i in `seq 20`; 
			do echo -n "="; 
		done; 
		
		echo; 
		mysqladmin stat &> /dev/null; 
		
		if [ $? == "1" ]; 
			then 
				echo "ERROR    Cant connect to mysql;"; 
				mysqladmin stat; 
			else 
				mysql -Nse "show variables like 'max_connections'" | awk '{print $1,"\t--\t",$2}'; 
				mysql -Nse "show status like 'max_used%'"| awk '{print $1,"\t--\t",$2}'; 
				echo -e "Mysql Uptime  \t\t--\t" `mysqladmin stat | awk '{print $2/60/60, "Hours"}' `; 
		fi;
		
		mysql_log=$(ps auxf | grep -i mysql | grep -i log | tr " " "\n"| grep -i error | cut -d "=" -f2);
		echo -e "\n\nLog file : $mysql_log\n\nRecent Errors from logs :"; 
		
		for i in `seq 25`; 
			do 
				echo -n "="; 
		done; 
		
		echo;
		timeout 5 grep -i error $mysql_log | grep $(date +%y%m%d) | tail -20 ;
		echo -e "\n\n(If any) Mysql Stop/starts today :" ; 
		
		for i in `seq 35`; 
			do 
				echo -n "="; 
		done; 
		echo; 

		### Finding db starts / shutdowns
		start_shut=`mktemp`; 
		timeout 5 egrep 'starting shutdown|ready for connections' -i $mysql_log | grep $(date +%y%m%d) > $start_shut ; 
		
		if [ ! -s $start_shut ]; 
			then 
				echo "None."; 
			else 
				cat $start_shut | tail -20; 
		fi; 
		
		rm -rf $start_shut;  
	
	elif [ ! -z "$db_temp" ]; 
		then 
			echo -e $db_temp "\n------> is insalled but not running."; 
			setto=$(chkconfig --list $(rpm -ql $db_temp | grep init.d | awk -F "/" '{print $(NF-0)}')); 
			setto_st=$(echo $setto | awk '{print $5}' |cut -d ":" -f2); 
			
			if [ $setto_st == "on" ]; 
				then 
					echo -e "\nAnd is set to on"; 
				else 
					ehco "\nAnd is not set to on"; 
			fi; 
	
			echo $setto | column -t; 
	else 
		echo  -e "\n\nMysql/Mariadb/Percona none of the database is even installed" ;
fi; 

##### Checking Holland now 
echo -e "\n\nChecking Holland..";  

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
		if [ $? == 0 ];
			then 
				last_log_gzip=yes; 
		fi; 
		

				### If main logfile is empty.. look for .gz files
		if [ -s $holl_log/holland.log ]; 
			then 
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
				
				for j in `cat d` ; 
					do 
						echo -e "\n$j\n"; 
						grep $j $log | egrep -i 'error|warning|complete|estimated|final'; 
						echo ""; 
					done;  
				
				rm -rf d; 
			elif [[ -s $last_log  && $last_log_gzip == yes ]]; 
				then 
					log=$last_log;
					echo $estimate; 
					backup_size=`zgrep -i final $log | tail -1 | awk '{print $(NF-0)}'`;
					echo -e "\nLast backup size is $backup_size"; 
					echo ""; 
					zcat $log | awk '{print $1}' | uniq | tail -2 > d; 
					
					for j in `cat d` ; 
						do 
							echo -e "\n$j\n"; 
							zgrep $j $log | egrep -i 'error|warning|complete|estimated|final'; 
							echo;
						done; 
					rm -rf  d;
		fi 
elif rpm -qa | grep mysqlbackup ; 
	then 
		echo -e "\nmysqlbackup installed. Check logs manually";  

elif ps auxf | grep mysql | egrep -v 'safe|grep'; 
	then 
		echo -e "\nNeither Holland Nor Mysqlbackup is installed but mysql is running.";  

else 
	echo -e "\nNeither Holland Nor Mysqlbackup is installed. However mysql is also not running."; 
fi;
