#!/bin/bash
echo starting up...
. korebit.conf
x=0
link="https://bitcointalk.org/index.php?topic=2096416.msg29423116#msg29423116" #link to btctalk release/post
#current block
cblock=$(curl -o- -s https://chainz.cryptoid.info/kore/api.dws?q=getblockcount)
#cycle count
cycle=0
#initiate minbal
minbal=0
#calculate seconds to run script
secs=$(($staketime * 60))
#calculate seconds to kill kore-qt
forcekill=$(($forced_shutdown * 60))
#staking setting
staking=0
trap 'tput sgr0; tput cnorm; tput rmcup || clear; exit 0' SIGINT
tput smcup; tput civis

tprint() {
tput bold; echo $1 $2; tput sgr0
}

splash()
{
clear
echo "  _  __   ___    ____    _____   _       _   _   "
echo " | |/ /  / _ \  |  _ \  | ____| | |__   (_) | |_ "
echo " | ' /  | | | | | |_) | |  _|   | '_ \  | | | __|"
echo " | . \  | |_| | |  _ <  | |___  | |_) | | | | |_ "
echo " |_|\_\  \___/  |_| \_\ |_____| |_.__/  |_|  \__|"
echo "                                                 "
echo ""
echo "Please have a LOCKED KORE wallet running when you start this script!!!!"
echo ""
echo ""
echo ""
echo "Temporary Cycling script by TheMatrix101"
echo ""
checks
}

checks()
{

if [ ! -d $bk_dir ]; then
		echo KORE backup Directory NOT found...Creating
		mkdir $bk_dir
		if [ -d $bk_dir ]; then
			echo KORE backup Directory created
		else
			echo ERROR creating Backup directory, please make $bk_dir and run this script again.
			exit
		fi
		echo backing up $kore_dir
		cp -r ${kore_dir}. ${bk_dir}
		if [ ! -f ${bk_dir}/wallet.dat ]; then
			echo ERROR Unable to verify backup of wallet.dat
			exit
		fi
fi

if ! command -v jq >/dev/null 2>&1; then
	echo ERROR JQ is not installed, korebit cannot continue
	echo ""
	echo Please install JQ and restart this script
	echo "sudo apt-get install jq -y"
	exit
fi

unlocked=$(kore-cli getinfo|jq ".unlocked_until")
if [ $unlocked == null ];then
	echo please do not use any wallet until you have encrypted it.
	exit
fi
pp
}

pp()
{
echo "Please enter the password to unlock your wallet for staking, If you input the incorrect password you will have the chance to update it"
echo "NOTE: for security reasons you will not be able to see the password as you put it in (this stops others from looking over your shoulder at it)"
read -s KOREPw
echo ""
echo ""
confpp
}

confpp()
{
read -p "Please confirm your password is ${#KOREPw} characters in length (Y/N)" chars
case ${chars:0:1} in
	y|Y )
		echo password saved in memory, when this program is stopped it will be destroyed
		setminbal
	;;
	n|N )
		pp
	;;
	* )
		echo "Not a valid choice, please use the y (yes) or n (no)"
		confpp
	;;
esac
}

setminbal()
{
	echo Please set your minimum balance before your wallet restarts
	read minbal
	echo minimum balance has been set to: $minbal
	echo initializing....
	main
}

main()
{
	while (( SECONDS < secs )); do
		#########################################################
		#####################   LOGIC   #########################
		cbal=$(kore-cli getbalance)
		currentbal=${cbal%.*}
		if (( $currentbal < $minbal ));then
			echo current balance below acceptible, restarting
			kk
		fi
		peers=$(kore-cli getconnectioncount)
		onionconns=$(kore-cli getpeerinfo|grep "addr"| grep .onion| grep -v addrlocal| wc -l)
		cblock=$(curl -o- -s https://chainz.cryptoid.info/kore/api.dws?q=getblockcount)
		lblock=$(kore-cli getblockcount)
		if (( $initforkdetect=0 ));then
			if (($peers > $initialize_fork_detection));then
				initforkdetect=1
			fi
		fi
		if (( $staking == 0 ));then
			SECONDS=0
			if (( $peers > $min_peers )) || (( $onionconns > $min_onions ));then
				if [ $lblock -ge $cblock ];then
					staking=1
					kore-cli walletpassphrase ${KOREPw} 10000
					SECONDS=0
				fi
			fi
		fi

		##########################################################
		#####################   /LOGIC   #########################
		clear
		tprint "KOREBit v3.0"
		echo ""
		echo ""
		tprint "Connections: " ${peers}
		tprint "Identified: " ${onionconns}
		echo ""
		echo ""
		tprint "Availible Balance: " ${currentbal}
		if (( $staking == 1 ));then
			tprint "Staking: " "true"
		else
			tprint "Staking: " "false"
		fi
		echo ""
		echo ""
		tprint "Current local block: " ${lblock}
		tprint "Current Chainz block: " ${cblock}
		echo ""
		echo ""
		tprint "Completed Cycles: " ${cycle}
		echo ""
		tilrestart=$(($secs - $SECONDS))
		if (( $staking == 1 ));then
			if (($tilrestart > 60));then
				tprint "Minutes till restart: " $(($tilrestart / 60))
			else
				tprint "Seconds till restart: " $tilrestart
			fi
		fi
		sleep 10
	done
	kk
}

sk() #start kore
{
	gnome-terminal -e './pt2.sh'
	((cycle++))
	clear
	tprint "KOREBit v3.0"
	echo ""
	echo ""
	tprint "Connections: " "0"
	tprint "Identified: " "0"
	echo ""
	echo ""
	tprint "Availible Balance: " "Unknown"
	tprint "Staking: " "false"
	echo ""
	echo ""
	tprint "Current local block: " "Unknown"
	tprint "Current Chainz block: " "Unknown"
	echo ""
	echo ""
	tprint "Completed Cycles: " ${cycle}
	tprint "Status: Waiting for connection to wallet"
	until kore-cli getinfo 2>/dev/null| grep "{" > /dev/null
	do
		sleep 1
	done
	SECONDS=0 #restart amount of time script has been running
	main
}

kk() #kill kore
{
	peers=0
	onionconns=0
	staking=0
	kore-cli walletlock
	sleep 5
	kore-cli stop
	SECONDS=0
	while (( SECONDS < forcekill )); do
		if ! pgrep "kore-qt" > /dev/null
		then
			sleep 2
			sk
		fi
		clear
		tprint "KOREBit v3.0"
		echo ""
		echo ""
		tprint "Connections: " "0"
		tprint "Identified: " "0"
		echo ""
		echo ""
		tprint "Availible Balance: " "Unknown"
		tprint "Staking: " "false"
		echo ""
		echo ""
		tprint "Current local block: " "Unknown"
		tprint "Current Chainz block: " "Unknown"
		echo ""
		echo ""
		tprint "Completed Cycles: " ${cycle}
		tprint "Status: " "Offline"
		sleep 5
	done
	killall kore-qt 2>&1 >/dev/null
	sleep 2
	sk
}

splash
