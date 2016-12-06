#!/bin/bash
# serio-test.sh - unit test for serio
#

verbose=0
if [ "x$1" == "x-v" ] ; then
	verbose=1
	shift
fi

if [ "x$1" == "x--debug" ] ; then
	set -x
	shift
fi

if [ "x$1" == "x-h" ] ; then
	echo "usage: serio-test.sh [-v] [--debug] [-h] [-nc]"
	echo "  -v       Be verbose"
       	echo "  --debug  Print each shell line as it is executed"
	echo "  -h       Show this usage help"
	echo "  -nc      Don't clean up test files"
	exit 1
fi

SERIAL_DEV=/dev/ttyACM1
target_dir=/home/a

FILELIST="file1 file2 file3"
FILELIST="file1 file2"

# set this to something to wait between operations
SLEEP_TIME=0
#SLEEP_TIME=30

# use this to control whether to use paranoid mode with serio
#PARANOID="-P"

# use this to control whether to use basic mode (minimal commands)
#BASIC="-B"
SERIO_ARGS="-y $SERIAL_DEV $PARANOID $BASIC -t 0.05"

function vecho {
	if [ $verbose -gt 0 ] ; then
		echo $@
	fi
}

# create test files
echo "  Creating files..."

# make a super-small, super-safe file for file1
echo "this is the first test file for serio" >file1

size=1
file_arr=($FILELIST)
unset file_arr[0]
for f in ${file_arr[@]} ; do
	vecho "Creating file ${f}"
	ddout="/dev/null"
	if [ $verbose -gt 0 ] ; then
		ddout="/dev/stdout"
	fi
	dd if=/dev/urandom of=${f} bs=1000 count=${size} >$ddout 2>&1
	size=$(( $size * 10 ))
	i=$(( $i + 1 ))
done

#########################
# test put and get
# run some put and get tests, timing them

#FILELIST="file1 file2 file3 file4"
#FILELIST=file1

test_num=1

echo "Putting files: $FILELIST"
##  put some files
for f in $FILELIST ; do
	vecho "Putting file ${f}"
	/usr/bin/time -f "      time for put of $f: %E" ./serio $SERIO_ARGS -p --source=$f --destination="${target_dir}/$f" ;
	sleep $SLEEP_TIME
done

## get some files
echo "Getting files: $FILE_LIST"
for f in $FILELIST ; do
	ret_filename="${f}-return"
	vecho "  Getting file ${f} (into $ret_filename)"
	/usr/bin/time -f "      time for get of $f: %E" ./serio $SERIO_ARGS -g --source="${target_dir}/$f" --destination=$ret_filename ;
	sleep $SLEEP_TIME

	if [ -e "$ret_filename" ] ; then
		echo "ok $test_num - get of file $ret_filename"
	else
		echo "not ok $test_num - get of file $ret_filename"
	fi
	test_num=$(( $test_num + 1 ))
done

if [ $verbose -gt 0 ] ; then
	echo "Here are the checksums of testfiles"
	cksum file*
fi

function check_cksum {
	local f="$1"
	local fr="${f}-return"

	local fs=$(cksum $f | cut -d " " -f 1,2)
	local frs=$(cksum $fr | cut -d " " -f 1,2)

	local desc="$test_num - check ${fr} cksum with ${f} cksum"
	if [ "${f1s}" = "${f1rs}" ] ; then
		echo "ok $desc"
	else
		echo "not ok $desc"
	fi
	test_num=$(( $test_num + 1 ))
}

for f in $FILELIST ; do
	check_cksum $f
done

#########################
# test some commands
#./serio $SERIO_ARGS -c "echo hello there!"

echo "  Executing some commands"
vecho "     Execute 'ls -l $target_dir'"
./serio $SERIO_ARGS -c "ls -l $target_dir"

vecho "     Execute 'echo hello there'"
res1=$(./serio $SERIO_ARGS -c "echo hello there")
exp1=$'hello there'

echo "expected  : [$exp1]"
echo "got result: [$res1]"

desc="$test_num - run 'echo hello there' on target"
if [ "$res1" = "$exp1" ] ; then
	echo "ok $desc"
else
	echo "not ok $desc"
fi

#########################
# test cleanup

function cleanup {
	# remove test files
	echo "Doing cleanup"
	./serio -y $SERIAL_DEV -c "rm ${target_dir}/file[12345]"
	rm file[12345]
	rm file[12345]-return
}

if [ ! "x$1" == "x-nc" ] ; then
	cleanup
fi
