#!/bin/bash
# serio-test.sh - unit test for serio


#_______________________________________________________________________________

function vecho {
	if [ $verbose -gt 0 ] ; then
		echo "$@"
	fi
}


function usage
{
echo "
usage: ${script_name} [-v] [--debug] [-h] [-nc]

   -B, --basic               *Use basic (minimal) remote system commands
   --debug                    Print each shell line as it is executed
   -F, --numfiles <count>     Number of random data test files
   -h, -help, --help          Show help
   --nc                       Don't clean up test files
   -s, --sleep <seconds>      Time to sleep between --get and --put tests [0.0]
   -T, --timeout <seconds>   *Timeout for serial port I/O operations
   -y, --port <serial port>  *Serial port to use [/dev/ttyUSB0]
   -R, --remote-dir <dir>     Directory on remote system to put files into [.]
   -v                         Be verbose

  * Sets a serio command line option

" >&2
}


#_______________________________________________________________________________

script_name=`basename $0`

#PARANOID="-P"

unset BASIC
unset SERIAL_DEV
unset PARANOID
unset SLEEP
unset TIMEOUT

do_cleanup=1
help=0
numfiles=2
remote_dir="."
verbose=0
while [ $# -gt 0 ] ; do

	case $1 in

		-B | --basic )
			shift
			BASIC="-B"
			;;

		--debug )
			shift
			set -x
			;;

		-F | --numfiles )
			shift
			numfiles=$1
			shift
			;;

		-h | -help | --help )
			shift
			help=1
			;;

		--nc )
			shift
			do_cleanup=0
			;;

		-P | --paranoid )
			PARANOID="-P"
			shift
			;;

		-s | --sleep )
			shift
			SLEEP="sleep $1"
			shift
			;;

		-T | --timeout )
			shift
			TIMEOUT="-T $1"
			shift
			verbose=1
			;;

		-R | --remote-dir )
			shift
			remote_dir="$1"
			shift
			verbose=1
			;;

		-v )
			shift
			verbose=1
			;;

		-y | --port )
			shift
			SERIAL_DEV="-y $1"
			shift
			verbose=1
			;;

		* )
			break
			;;

		esac
done


if [ $help -eq 1 ] ; then
	usage
	exit 1
fi

if [ $# -ne 0 ] ; then
	echo "ERROR: unexpected parameter:"                                  >&2
	echo "       $@"                                                     >&2
	exit 1
fi

# FIXME - Should have an option to do something analagous to mktemp on the
# target, but do not want to add "mktemp" dependency on remote system, so
# can hand craft with something like:

#     $remote_dir="${remote_dir}/tmp"
#     $SERIO $SERIAL_DEV -c 'if [ -f tmp -o -d tmp ] ; then echo error ; else mkdir tmp ; echo ok ; fi'
#
#     then modify cleanup() to: $SERIO $SERIAL_DEV -c 'rm -r ${remote_dir}'

tmp_dir=$( mktemp --tmpdir -d serio-test.XXXXXXXXXX )


FILE_LIST=""
for k in $(seq ${numfiles}) ; do
	FILE_LIST="${FILE_LIST} file_${k}"
done


SERIO_ARGS="$SERIAL_DEV $PARANOID $BASIC $TIMEOUT"

# shell builtin 'time' does not recognize -f
TIME="/usr/bin/time"

# respect $PATH
SERIO=$( which serio )

# if serio is not on the PATH, then try using it from 
# the current directory.  This way, even if serio is
# not installed, there's a chance that serio-test.sh will work
if [ -z "${SERIO}" ] ; then
	SERIO=./serio
fi

vecho "remote-dir = ${remote_dir}"
vecho "FILE_LIST  = ${FILE_LIST}"
vecho "SERIAL_DEV = ${SERIAL_DEV}"
vecho "SERIO_ARGS = ${SERIO_ARGS}"
vecho "SLEEP      = ${SLEEP}"
vecho "SERIO      = ${SERIO}"


#########################
# create test files

echo "Creating files..."

# make a super-small, super-safe file for file1
echo "this is the first test file for serio" >${tmp_dir}/file_short

if [ $verbose -gt 0 ] ; then
	ddout="/dev/stdout"
else
	ddout="/dev/null"
fi

size=1
for f in ${FILE_LIST} ; do
	f_full="${tmp_dir}/$f"
	vecho "Creating file ${f}"
	dd if=/dev/urandom of=${f_full} bs=1000 count=${size} >$ddout 2>&1
	size=$(( $size * 10 ))
	i=$(( $i + 1 ))
done

FILE_LIST="file_short ${FILE_LIST}"


#########################
# test put and get
# run some put and get tests, timing them

# FIXME- In the result messages:
#          suggest "PASS" instead of "ok"
#          suggest "FAIL" instead of "not ok"
#
#     I would have made those changes myself, but we have had the discussion
#     about the lack of consistency in test pass/fail messages across test
#     projects, so I figured this might not be as obvious as what I am
#     suggesting.
#
# FIXME - Suggest less verbosity and reordering for easier parsing of the messages,
#         eg s/time for get of $f: %E/time | %E | get $f/

test_num=1

##  put some files

echo "Putting files: $FILE_LIST"
for f in $FILE_LIST ; do
	f_full="${tmp_dir}/$f"
	vecho "Putting file ${f}"
	${TIME} -f "      time for put of $f: %E" $SERIO $SERIO_ARGS -p --source=$f_full --destination="${remote_dir}/$f" ;
	$SLEEP
done

## get some files

echo "Getting files: $FILE_LIST"
for f in $FILE_LIST ; do
	ret_f="${f}-return"
	ret_f_full="${tmp_dir}/${ret_f}"
	vecho "  Getting file ${f} (into $ret_f)"
	${TIME} -f "      time for get of $f: %E" $SERIO $SERIO_ARGS -g --source="${remote_dir}/$f" --destination=$ret_f_full ;
	$SLEEP

	if [ -e "$ret_f_full" ] ; then
		echo "ok $test_num - get of file $ret_f"
	else
		echo "not ok $test_num - get of file $ret_f"
	fi
	test_num=$(( $test_num + 1 ))
done

if [ $verbose -gt 0 ] ; then
	echo "Here are the checksums of testfiles"
	cksum file*
fi

function check_cksum {
	local f="$1"
	local ret_f="${f}-return"
	local f_full="${tmp_dir}/${f}"
	local ret_f_full="${tmp_dir}/${ret_f}"

	local f_s=$(cksum $f_full | cut -d " " -f 1,2)
	local ret_f_s=$(cksum $ret_f_full | cut -d " " -f 1,2)

	local desc="$test_num - check ${ret_f} cksum with ${f} cksum"
	if [ "${f_s}" == "${ret_f_s}" ] ; then
		echo "ok $desc"
	else
		echo "not ok $desc"
	fi
	test_num=$(( $test_num + 1 ))
}

for f in $FILE_LIST ; do
	check_cksum $f
done

#########################
# test some commands
#$SERIO $SERIO_ARGS -c "echo hello there!"

echo "Executing some commands"
vecho "     Execute 'ls -l $remote_dir'"
$SERIO $SERIO_ARGS -c "ls -l $remote_dir"

vecho "     Execute 'echo hello there'"
res=$($SERIO $SERIO_ARGS -c "echo hello there")
rcode=$?
exp=$'hello there'

echo "expected  : [$exp], rcode=[0]"
echo "got result: [$res], rcode=[$rcode]"

desc="$test_num - run 'echo hello there' on remote"
if [ "$res" = "$exp" -a "$rcode" = "0" ] ; then
	echo "ok $desc"
else
	echo "not ok $desc"
fi
test_num=$(( $test_num + 1 ))

vecho "     Execute 'echo foo ; false'"
res=$($SERIO $SERIO_ARGS -c "echo foo ; false")
rcode=$?
exp=$'foo'
expcode=1

echo "expected  : [$exp], rcode=[$expcode]"
echo "got result: [$res], rcode=[$rcode]"

desc="$test_num - run 'echo foo ; false' on remote"
if [ "$res" = "$exp" -a "$rcode" = "$expcode" ] ; then
	echo "ok $desc"
else
	echo "not ok $desc"
fi
test_num=$(( $test_num + 1 ))

#########################
# test cleanup

function cleanup {
	# remove test files

	$SERIO $SERIAL_DEV -c "rm ${remote_dir}/file_[1-9]* ${remote_dir}/file_short"

	rm -r ${tmp_dir}
}

if [ $do_cleanup -eq 1 ] ; then
	echo "Doing cleanup"
	cleanup
else
	echo "Not doing cleanup, test files are in ${tmp_dir}"
fi
