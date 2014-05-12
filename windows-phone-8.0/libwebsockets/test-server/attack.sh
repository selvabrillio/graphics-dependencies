#!/bin/sh
#
# attack the test server and try to make it fall over
#
SERVER=127.0.0.1
PORT=7681
LOG=/tmp/lwslog

CPID=
LEN=0

function check {
	kill -0 $CPID
	if [ $? -ne 0 ] ; then
		echo "(killed it) *******"
		exit 1
	fi
	dd if=$LOG bs=1 skip=$LEN 2>/dev/null
	LEN=`stat $LOG -c %s`
}


rm -rf $LOG
killall libwebsockets-test-server 2>/dev/null
libwebsockets-test-server -d31 2>> $LOG &
CPID=$!

while [ -z "`grep Listening $LOG`" ] ; do
	sleep 0.5s
done
check

echo
echo "---- spam enough crap to not be GET"
echo "not GET" | nc $SERVER $PORT
check

echo
echo "---- spam more than the name buffer of crap"
dd if=/dev/urandom bs=1 count=80 2>/dev/null | nc -i1s $SERVER $PORT
check

echo
echo "---- spam 10MB of crap"
dd if=/dev/urandom bs=1 count=655360 | nc -i1s $SERVER $PORT
check

echo
echo "---- malformed URI"
echo "GET nonsense................................................................................................................" \
	| nc -i1s $SERVER $PORT
check

echo
echo "---- missing URI"
echo -e "GET HTTP/1.1\x0d\x0a\x0d\x0a" | nc -i1s $SERVER $PORT >/tmp/lwscap
check

echo
echo "---- repeated method"
echo -e "GET blah HTTP/1.1\x0d\x0aGET blah HTTP/1.1\x0d\x0a\x0d\x0a" | nc $SERVER $PORT >/tmp/lwscap 
check

echo
echo "---- crazy header name part"
echo -e "GET blah HTTP/1.1\x0d\x0a................................................................................................................" \
	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 | nc -i1s $SERVER $PORT
check

echo
echo "---- excessive uri content"
echo -e "GET ................................................................................................................" \
	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 | nc -i1s $SERVER $PORT
check

echo
echo "---- good request but http payload coming too (should be ignored and test.html served)"
echo -e "GET blah HTTP/1.1\x0d\x0a\x0d\x0aILLEGAL-PAYLOAD........................................" \
	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
 	"......................................................................................................................." \
	 | nc $SERVER $PORT | sed '1,/^\r$/d'> /tmp/lwscap
check
diff /tmp/lwscap /usr/share/libwebsockets-test-server/test.html > /dev/null
if [ $? -ne 0 ] ; then
	echo "FAIL: got something other than test.html back"
	exit 1
fi

echo
echo "---- directory attack"
rm -f /tmp/lwscap
echo -e "GET ../../../../etc/passwd HTTP/1.1\x0d\x0a\x0d\x0a" | nc $SERVER $PORT | sed '1,/^\r$/d'> /tmp/lwscap
check
diff /tmp/lwscap /usr/share/libwebsockets-test-server/test.html > /dev/null
if [ $? -ne 0 ] ; then
	echo "FAIL: got something other than test.html back"
	exit 1
fi

echo
echo "--- survived"
kill -2 $CPID

