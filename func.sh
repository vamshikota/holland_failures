#!/bin/bash


#lines() { for i in $(seq $1); do echo -n "="; done; echo;}
#lines $1

clear
echo $1

load()
{
	uptime;
	iowait;
			
} 

disk ()
{
	df -h;
	lsblk; 
	
}

helper()
{
echo -e "Choose the options from: 
			--load
			--disk"
}

case $1 in 
	"--load")
		load
		;;
	"--disk")
		disk
		;;
	*)
		helper
		;;
esac

