#!/bin/bash

init_hips(){
	if [[ "$EUID" -ne 0 ]]; then
		echo "Error: Script must be ran as super user or root." >&2
		exit 1
	fi

	if ! ps -C sshd > /dev/null; then
		echo "Error: SSHD isn't running." >&2
		exit 2
	fi

	if ! command -v iptables > /dev/null; then
		echo "Error: iptables not found." >&2
		exit 3
	fi

	if ! command -v ip6tables > /dev/null; then
		echo "Error: ip6tables not found." >&2
		exit 4
	fi

	if [[ ! -f /etc/hips.conf ]]; then
		touch /etc/hips.conf
		echo "TIME_WINDOW=60" >> /etc/hips.conf
		echo "MAX_TRIES=3" >> /etc/hips.conf
		echo "BLOCK_DURATION=30" >> /etc/hips.conf
		echo "The config file can be edited at /etc/hips.conf."
	fi

	while IFS='=' read -r key value; do
    		case "$key" in
        		TIME_WINDOW) TIME_WINDOW="$value";;
        		MAX_TRIES) MAX_TRIES="$value";;
        		BLOCK_DURATION) BLOCK_DURATION="$value";;
    		esac
	done < /etc/hips.conf

	TIME_WINDOW=${TIME_WINDOW:-60}
	MAX_TRIES=${MAX_TRIES:-3}
	BLOCK_DURATION=${BLOCK_DURATION:-30}
	readonly TIME_WINDOW MAX_TRIES BLOCK_DURATION

	if [[ ! -d /var/tmp/hips ]]; then
		mkdir /var/tmp/hips
	fi

	if [[ ! -f /var/tmp/hips/hips.db ]]; then
		touch /var/tmp/hips/hips.db
	fi

	if [[ ! -f /var/tmp/hips/hips.log ]]; then
		touch /var/tmp/hips/hips.log
	fi
}

read_logs(){
	if command -v journalctl > /dev/null; then
		journalctl -u sshd -f --output cat
	else
		tail -n 0 -f /var/log/auth.log
	fi
}

check_failed_attempts(){
	read_logs | while IFS= read -r line; do
		if [[ "$line" =~ "Failed password" ]]; then
			process_failed_attempt "$line"
		fi
	done
}

process_failed_attempt(){
	TIME=$(date +"%Y-%m-%d %H:%M:%S")
	IP=$(echo "$1" | sed "s/.* from //; s/ port .*//")
	
	check_time_window "$TIME" "$IP" && sed -i "/.* $IP .*/d" /var/tmp/hips/hips.db

	IP_DB=$(grep "$IP" /var/tmp/hips/hips.db || echo "$TIME $IP 0")	

	FAILURES=$(echo "$IP_DB" | awk -F' ' '{print $4}')

	FAILURES=$(("$FAILURES" + 1))

	sed -i "/.* $IP .*/d" /var/tmp/hips/hips.db
	echo "$TIME $IP $FAILURES" | tee -a /var/tmp/hips/hips.db > /dev/null

	[[ "$FAILURES" -ge "$MAX_TRIES" ]] && block_ip "$TIME" "$IP" "$FAILURES"
}

check_time_window(){
	if grep -q "$2" /var/tmp/hips/hips.db; then
		NOW=$(date -d "$1" +"%s")
		PREVIOUS=$(date -d "$(grep "$2" /var/tmp/hips/hips.db | awk -F' ' '{print $1, $2}')" +"%s")

		DIFF=$(("$NOW" - "$PREVIOUS"))
		[[ "$DIFF" -ge "$TIME_WINDOW" ]] && return 0
	fi
	return 1
}

block_ip(){
	if [[ "$2" =~ ":" ]]; then
		CMD="ip6tables"
	else
		CMD="iptables"
	fi

	"$CMD" -A INPUT -s "$2" -j DROP
	echo "[$1] $3 Failed password attempts from $2, IP blocked for $BLOCK_DURATION seconds." | tee -a /var/tmp/hips/hips.log > /dev/null

	(sleep "$BLOCK_DURATION"; "$CMD" -D INPUT -s "$2" -j DROP) &
}

init_hips
check_failed_attempts
