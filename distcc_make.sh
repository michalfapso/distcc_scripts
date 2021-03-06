#!/bin/bash

# distcc_make
#
# Compile locally when all compile jobs can run simultaneously
# on the local machine, otherwise submit jobs over the network

# echo "args: $@"
# echo "pwd: $PWD"

TMP_DIR=`mktemp -d /tmp/distcc_make.XXXXXXX`
mkdir -p $TMP_DIR

ARGS_WITHOUT_J="`echo "$@" | sed 's/-j[0-9]\+//'`"
ARG_J="`echo $@ | awk '{match($0, /-j([0-9]+)/, a); print a[1];}'`"

# echo "ARGS_WITHOUT_J:$ARGS_WITHOUT_J"

# echo "make --just-print"
# time \
(
make --just-print $ARGS_WITHOUT_J > "$TMP_DIR/commands.list"
)
JOBS_COUNT="`cat "$TMP_DIR/commands.list" | grep '^distcc' | wc -l`"
CORES_COUNT_LOCAL="`nproc`"
CORES_COUNT_REMOTE="`distcc -j`"

echo "CORES_COUNT_LOCAL:$CORES_COUNT_LOCAL CORES_COUNT_REMOTE:$CORES_COUNT_REMOTE JOBS_COUNT:$JOBS_COUNT"

# Determine whether to distribute jobs or run locally
if [[ ("$CORES_COUNT_LOCAL" -ge "$JOBS_COUNT") || ("$CORES_COUNT_LOCAL" -ge "$CORES_COUNT_REMOTE") ]]; then
	echo "Run locally"
	export DISTCC_HOSTS="localhost/$CORES_COUNT_LOCAL"
	if [ -z "$ARG_J" ]; then
		ARG_J="$CORES_COUNT_LOCAL"
	fi
else
	echo "Submit jobs over network"
	#if [ -z "$ARG_J" ]; then
		ARG_J="$CORES_COUNT_REMOTE"
	#fi
	echo "Settings parallel jobs count to $ARG_J"
fi

# echo "DISTCC_HOSTS:$DISTCC_HOSTS"


#if ! type "parallel" > /dev/null; then
if [ 1 ]; then
	# If GNU Parallel is not installed, use make instead. This is a bit slower, because make was already executed above and is going to be executed again here
	echo make -j$ARG_J $ARGS_WITHOUT_J
	make -j$ARG_J $ARGS_WITHOUT_J
	ok="$?"
	if [ "$ok" -ne 0 ]; then
		echo "make failed. exiting"
		exit $ok
	fi
else
	# echo 'will cite' | parallel --citation

	IFS=$'\n'
	cat $TMP_DIR/commands.list | awk 'BEGIN{ end = 0 }
		/^distcc/ {
			print > "'$TMP_DIR'/commands.list.distcc";
			end = 1;
			next
		}
		end == 0 {print > "'$TMP_DIR'/commands.list.start"}
		end == 1 {print > "'$TMP_DIR'/commands.list.end"}'

	# Hack to keep colored gcc output in GNU Parallel
	if [ "$TERM" == "xterm" ]; then
		sed -i 's/^\(distcc [^ ]*g++[^ ]*\)\(.*\)/\1 -fdiagnostics-color=always \2/' $TMP_DIR/commands.list.distcc
	fi

	if [ 1 ]; then
		echo "start:" ; cat $TMP_DIR/commands.list.start
		echo "distcc:"; cat $TMP_DIR/commands.list.distcc
		echo "end:"   ; cat $TMP_DIR/commands.list.end
		echo ""
	fi

	# Process serial commands
	if [ -e "$TMP_DIR/commands.list.start" ]; then
		for cmd in `cat $TMP_DIR/commands.list.start`; do
			echo $cmd
			eval $cmd
			if [ $? -ne 0 ]; then
				break
			fi
		done
	fi

	# Process parallel commands
	cat $TMP_DIR/commands.list.distcc | parallel --max-procs "$ARG_J" --halt now,fail=1 --verbose
	ok="$?"
	if [ "$ok" -ne 0 ]; then
		echo "exit code:$ok"
		echo "exiting make"
		exit $ok
	fi
	echo "running parallel jobs...done"

	# Process serial commands
	for cmd in `cat $TMP_DIR/commands.list.end`; do
		echo $cmd
		eval $cmd
		if [ $? -ne 0 ]; then
			break
		fi
	done
fi

rm -r $TMP_DIR
