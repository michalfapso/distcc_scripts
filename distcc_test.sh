#!/bin/bash

# distcc_test
#
# Periodically checks distcc hosts and updates ~/.distcc/hosts file accordingly.
# Install the service using ./distcc_test.sh --install-service

if [ "$1" == "--install-service" ]; then
	cp "$0" "/usr/bin/"

	cygrunsrv.exe -I distccd_test -p /usr/bin/bash.exe -a "`basename $0`" -e PATH=$PATH -e HOME=$HOME
	if [ $? == 0 ]; then
		echo "Successfully installed"
	else
		echo "Install failed" >&2
		exit 1
	fi

	net start distccd_test
	if [ $? == 0 ]; then
		echo "Successfully executed"
	else
		echo "Execution failed" >&2
		exit 1
	fi
	exit
fi

TMP_DIR=`mktemp -d /tmp/distcc_test.XXXXXXX`
echo "TMP_DIR:$TMP_DIR"
mkdir -p $TMP_DIR

cd $TMP_DIR

cat > Makefile << EOF
CXX = distcc g++

main.exe: main.o
	\$(CXX) -o \$@ \$^

main.o: main.cpp
	\$(CXX) -o \$@ -c \$^

.PHONY: clean

clean:
	rm *.o *.exe
EOF

cat > main.cpp << EOF
#include <iostream>

int main(int argc, char** argv)
{
	std::cout << "main()" << std::endl;
	return 0;
}
EOF

#cat Makefile
#cat main.cpp

(
while [ 1 ]; do
	date +%Y-%m-%d_%H:%M:%S

	(
	for host in `cat ~/.distcc/hosts.all`; do
		make clean >/dev/null 2>&1
		export DISTCC_HOSTS="$host"
		export DISTCC_VERBOSE=1
		echo -n "$DISTCC_HOSTS "
		make main.o 2>&1 \
			| tee out.log \
			| awk '
				#{print}
				/^distcc.*\(dcc_note_state\) note state 2, file/ { ok=1; }
				/^distcc.*compiled on/                           { ok=1; }
				/failed to distribute/                           { ok=0; }
				/running locally instead/                        { ok=0; }
				/still in backoff period/                        { ok=0; }
				END { if(ok) { print "OK" } else { print "BAD" } }
			'

		#	| grep -E '^distcc.*\(dcc_note_state\) note state 2, file|^distcc.*compiled on|failed to distribute|running locally instead|still in backoff period'
		#cat out.log
		#exit
	done
	) \
	| tee /dev/stderr \
	| awk '$2 == "OK" { print $1 }' \
	> hosts.tmp

	(
		for local_hostname in "`hostname`" "localhost" "127.0.0.1"; do
			echo '^'"$local_hostname"'\(/.*\)\?' >> "local_hostnames"
		done

		# filter-out local hostname
		cat hosts.tmp \
		| grep -i -v -f local_hostnames \
		> hosts_nolocal.tmp

		# Hosts file should be filled only when there are some non-local hostnames in the list
		if [ ! -z "`cat hosts_nolocal.tmp`" ]; then
			echo "--randomize"
			cat hosts_nolocal.tmp
		fi

		# Localhost
		local_threads_count="`nproc`"
		if [ "$local_threads_count" -ge 3 ]; then
			echo "localhost/`echo $local_threads_count / 2 | bc`"
		fi
	) > ~/.distcc/hosts

	echo "sleeping..."
	sleep 5m
	echo ""
done
) 2>&1 | tee /var/log/distcc_test.log

rm -r $TMP_DIR

