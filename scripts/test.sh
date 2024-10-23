#!/usr/bin/env bash

SOURCE_FILE=/tmp/.relkfile
NS="testrun"
FLAGS="-n $NS -s file:$SOURCE_FILE"

echo "Relk Test Script"

###############################################################################

echo ""
echo "get-keys:"

###############################################################################
TESTNAME="get-keys should return nothing when there are no keys"

# arrange
echo "" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-keys $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-keys should return keys when there are keys"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-keys $FLAGS)

# assert
if [ "$RESULT" != "key1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################

echo ""
echo "get-key:"

###############################################################################
TESTNAME="get-key should return an error when the key does not exist"

# arrange
echo "" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 $FLAGS 2>&1)

# assert
if [ "$?" -ne 4 ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an error when the key name is invalid"

# arrange
echo "" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key "{testkey}" $FLAGS)

# assert
if [ "$?" -ne 6 ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an empty key value when it exists"

# arrange
echo "$NS|key1||s||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi


###############################################################################
TESTNAME="get-key should return a value which contains a single quote when it exists"

# arrange
echo "$NS|key1|'myvalue'|s||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "'myvalue'" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists and has constraints"

# arrange
echo "" > $SOURCE_FILE
echo "$NS|key1|valuedev|s||env=dev" >> $SOURCE_FILE
echo "$NS|key1|valuetest|s||env=test" >> $SOURCE_FILE
echo "$NS|key1|valueprod|s||env=prod" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 -k env=dev $FLAGS)

# assert
if [ "$RESULT" != "valuedev" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not return key value when it exists but has constraints that don't match"

# arrange
echo "" > $SOURCE_FILE
echo "$NS|key1|valuedev|s||env=dev" >> $SOURCE_FILE
echo "$NS|key1|valuetest|s||env=test" >> $SOURCE_FILE
echo "$NS|key1|valueprod|s||env=prod" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 -k env=invalid $FLAGS 2>&1)

# assert
if [ "$?" -eq 0 ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists and requested constraints do not apply"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 -k env=dev $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists and has a subset of constraints"

# arrange
echo "" > $SOURCE_FILE
echo "$NS|key1|value6|s||k1=v3,k2=something,k3=another" >> $SOURCE_FILE
echo "$NS|key1|value5|s||k1=v3,k2=something" >> $SOURCE_FILE
echo "$NS|key1|value4|s||k1=v3" >> $SOURCE_FILE
echo "$NS|key1|value3|s||k1=v2" >> $SOURCE_FILE
echo "$NS|key1|value2|s||k1=v1" >> $SOURCE_FILE
echo "$NS|key1|value1|s||" >> $SOURCE_FILE

# act
RESULT1=$(./dist/relk get-key key1 $FLAGS)
RESULT2=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)
RESULT3=$(./dist/relk get-key key1 -k k1=v2 $FLAGS)
RESULT4=$(./dist/relk get-key key1 -k k1=v3 $FLAGS)
RESULT5=$(./dist/relk get-key key1 -k k1=v3 -k k2=something $FLAGS)
RESULT6=$(./dist/relk get-key key1 -k k1=v3 -k k2=something -k k3=another $FLAGS)

# assert
if [ "$RESULT1" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 1: $RESULT1"
    exit 1
elif [ "$RESULT2" != "value2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 2: $RESULT2"
    exit 1
elif [ "$RESULT3" != "value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 3: $RESULT3"
    exit 1
elif [ "$RESULT4" != "value4" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 4: $RESULT4"
    exit 1
elif [ "$RESULT5" != "value5" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 5: $RESULT5"
    exit 1
elif [ "$RESULT6" != "value6" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 6: $RESULT6"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value when it exists"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|{key1}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value with : when it exists"

# arrange
echo "$NS|key1|value:1|s||" > $SOURCE_FILE
echo "$NS|key2|{key1}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ "$RESULT" != "value:1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template with an empty value when it exists"

# arrange
echo "$NS|key1||s||" > $SOURCE_FILE
echo "$NS|key2|{key1}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not allow command injection in templates"

# arrange
touch /tmp/TESTFILE
# key1 has a value that attempts to execute a command
echo "$NS|key1|\$(rm /tmp/TESTFILE)|t||" > $SOURCE_FILE
echo "$NS|key2|{key1}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ -f "/tmp/TESTFILE" ]; then
    echo " [✓] $TESTNAME"
else
    echo " [x] $TESTNAME"
    echo "Potential vulnerability: $RESULT"
    exit 1
fi

###############################################################################
TESTNAME="get-key should not allow command injection in template environment variable"

# arrange
touch /tmp/ENV_TESTFILE
export RELK_ENV_CMD="\$(rm /tmp/ENV_TESTFILE)"
echo "$NS|key1|{\$RELK_ENV_CMD}|t||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ -f "/tmp/ENV_TESTFILE" ]; then
    echo " [✓] $TESTNAME"
else
    echo " [x] $TESTNAME"
    echo "Potential vulnerability: $RESULT"
    exit 1
fi

###############################################################################
TESTNAME="get-key should return an evaluated sed template value when it exists"

# arrange
echo "$NS|key1|food|s||" > $SOURCE_FILE
echo "$NS|key2|{key1:#s/foo/bar/g}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ "$RESULT" != "bard" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated sed template value with : when it exists"

# arrange
echo "$NS|key1|foo:|s||" > $SOURCE_FILE
echo "$NS|key2|{key1:#'s/:/bar/g'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ "$RESULT" != "foobar" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi


###############################################################################
TESTNAME="get-key should return an evaluated sed template value with special characters when it exists"

# arrange
echo "$NS|key1|part1-part2-part3|s||" > $SOURCE_FILE
echo "$NS|part1|{key1:#s/^([^-]+)-.*/\1/}|t||" >> $SOURCE_FILE
echo "$NS|part2|{key1:#s/-/&\n/;s/.*\n//;s/-/\n&/;s/\n.*//}|t||" >> $SOURCE_FILE
echo "$NS|part3|{key1:#s/[^-]*-[^-]*-(.*)/\1/}|t||" >> $SOURCE_FILE

# act
RESULT1=$(./dist/relk get-key part1 $FLAGS)
RESULT2=$(./dist/relk get-key part2 $FLAGS)
RESULT3=$(./dist/relk get-key part3 $FLAGS)

# assert
if [ "$RESULT1" != "part1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result1: $RESULT1"
    exit 1
elif [ "$RESULT2" != "part2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result2: $RESULT2"
    exit 1
elif [ "$RESULT3" != "part3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result3: $RESULT3"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not allow command injection through sed command"

# arrange
touch /tmp/SED_TESTFILE
echo "$NS|key1|test value|s||" > $SOURCE_FILE
echo "$NS|key2|{key1:#s/test/value/g\" && rm \"/tmp/SED_TESTFILE}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS &> /dev/null)

# assert
if [ -f "/tmp/SED_TESTFILE" ]; then
    echo " [✓] $TESTNAME"
else
    echo " [x] $TESTNAME"
    echo "Potential vulnerability: $RESULT"
    exit 1
fi

###############################################################################
TESTNAME="get-key should not return an evaluated default template value when the expected value exists"

# arrange
echo "$NS|key1|expected value|s||" > $SOURCE_FILE
echo "$NS|key2|{key1:='default value'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ "$RESULT" != "expected value" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated default template value when the expected value does not exist"

# arrange
echo "$NS|key1||s||" > $SOURCE_FILE
echo "$NS|key2|{key1:='default value'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ "$RESULT" != "default value" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not allow command injection through a default template value"

# arrange
touch /tmp/DEF_TESTFILE
echo "$NS|key1||s||" > $SOURCE_FILE
echo "$NS|key2|{key1:=\" && rm /tmp/DEF_TESTFILE}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 $FLAGS)

# assert
if [ -f "/tmp/DEF_TESTFILE" ]; then
    echo " [✓] $TESTNAME"
else
    echo " [x] $TESTNAME"
    echo "Potential vulnerability: $RESULT"
    exit 1
fi

###############################################################################
TESTNAME="get-key should not allow command injection in template environment variable default value"

# arrange
touch /tmp/ENV_TESTFILE
# attempt command injection via an environment variable
export RELK_ENV_VAR="\$(rm /tmp/ENV_TESTFILE)"
echo "$NS|key1|{value:=\$RELK_ENV_VAR}|t||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 -k value="" $FLAGS)

# assert
if [ -f "/tmp/ENV_TESTFILE" ]; then
    echo " [✓] $TESTNAME"
else
    echo " [x] $TESTNAME"
    echo "Potential vulnerability: $RESULT"
    exit 1
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value when it exists with constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key1|value2|s||k1=v1" >> $SOURCE_FILE
echo "$NS|key2|{key1}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key2 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value with mulitple references when it exists with constraints"

# arrange
echo "$NS|key1|value0|s||" > $SOURCE_FILE
echo "$NS|key1|value1|s||k1=v1" >> $SOURCE_FILE
echo "$NS|key2|value2|s||k1=v1" >> $SOURCE_FILE
echo "$NS|key3|value3|s||k1=v1" >> $SOURCE_FILE
echo "$NS|key4|{key1}{key2}{key3}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key4 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1value2value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value within a template value when it exists with constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key1|value2|s||k1=v1" >> $SOURCE_FILE
echo "$NS|key2|{key1}|t||" >> $SOURCE_FILE
echo "$NS|key3|{key2}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should handle cycle detection resolution gracefully"

# arrange
echo "$NS|key1|{key2}|t||" > $SOURCE_FILE
echo "$NS|key2|{key1}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return a value piped from a shell when it exists with constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|yes|s||" >> $SOURCE_FILE
echo "$NS|key3|{key1:base64}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 --allow-shell $FLAGS)

# assert
if [ "$RESULT" != "dmFsdWUxCg==" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not allow shell commands if the --allow-shell flag is not set"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|yes|s||" >> $SOURCE_FILE
echo "$NS|key3|{key1:base64}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 $FLAGS &> /dev/null)

# assert
if [ "$?" -ne 8 ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not allow conditional expressions if the --allow-shell flag is not set"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|yes|s||" >> $SOURCE_FILE
echo "$NS|key3|{key1:?key2 = 'yes'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 $FLAGS &> /dev/null)

# assert
if [ "$?" -ne 8 ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not allow shell commands if the --no-shell flag is set"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|yes|s||" >> $SOURCE_FILE
echo "$NS|key3|{key1:base64}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 --no-shell --allow-shell $FLAGS &> /dev/null)

# assert
if [ "$?" -ne 8 ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not allow conditional expressions if the --no-shell flag is set"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|yes|s||" >> $SOURCE_FILE
echo "$NS|key3|{key1:?key2 = 'yes'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 --allow-shell --no-shell $FLAGS &> /dev/null)

# assert
if [ "$?" -ne 8 ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an conditionally rendered template value when it exists with constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|yes|s||" >> $SOURCE_FILE
echo "$NS|key3|{key1:?key2 = 'yes'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 --allow-shell $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an conditionally rendered template value when it exists with specified constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key3|{key1:?key2 = 'yes'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 --allow-shell -k key2=yes $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not return an conditionally rendered template value without constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key2|no|s||" >> $SOURCE_FILE
echo "$NS|key3|{key1:?key2 = 'yes'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 --allow-shell $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not return an conditionally rendered template value without specified constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE
echo "$NS|key3|{key1:?key2 = 'yes'}|t||" >> $SOURCE_FILE

# act
RESULT=$(./dist/relk get-key key3 --allow-shell -k key2=no $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################

echo ""
echo "set-key:"

###############################################################################
TESTNAME="set-key should set a string value when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key key1 value1 $FLAGS
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a string value when it already exists without being forced"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE

# act
./dist/relk set-key key1 NEWVALUE $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a string value when it already exists if forced"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE

# act
./dist/relk set-key key1 NEWVALUE -f $FLAGS
RESULT=$(./dist/relk get-key key1 $FLAGS)
SOURCE_RESULT=$(cat "$SOURCE_FILE")

# assert
if [ "$RESULT" != "NEWVALUE" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
elif [ "$SOURCE_RESULT" != "$NS|key1|NEWVALUE|s||" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected source result: $SOURCE_RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a string value when it already exists with different constraints"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE

# act
./dist/relk set-key key1 NEWVALUE -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "NEWVALUE" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a string value when it already exists with the same constraints without being forced"

# arrange
echo "$NS|key1|value1|s||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key key1 NEWVALUE -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a string value which contains spaces when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key "key 1" "value 1" $FLAGS
RESULT=$(./dist/relk get-key "key 1" $FLAGS)

# assert
if [ "$RESULT" != "value 1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a list value when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key key1 -l "value1,value2,value3" $FLAGS
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value2
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a list value when it already exists without being forced"

# arrange
echo "$NS|key1|value1,value2,value3|l||" > $SOURCE_FILE

# act
./dist/relk set-key key1 -l "NEWVALUE" $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value2
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a list value when it already exists if forced"

# arrange
echo "$NS|key1|value1,value2,value3|l||" > $SOURCE_FILE

# act
./dist/relk set-key key1 -l "NEWVALUE" -f $FLAGS
RESULT=$(./dist/relk get-key key1 $FLAGS)
SOURCE_RESULT=$(cat "$SOURCE_FILE")

# assert
if [ "$RESULT" != "NEWVALUE" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
elif [ "$SOURCE_RESULT" != "$NS|key1|NEWVALUE|l||" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected source result: $SOURCE_RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a list value when it already exists with different constraints"

# arrange
echo "$NS|key1|value1,value2,value3|l||" > $SOURCE_FILE

# act
./dist/relk set-key key1 -l "NEWVALUE" -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "NEWVALUE" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a list value when it already exists with the same constraints without being forced"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key key1 -l "NEWVALUE" -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value2
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a list value which contains spaces when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key "key 1" -l "value 1,value 2,value 3" $FLAGS
RESULT=$(./dist/relk get-key "key 1" $FLAGS)

# assert
if [ "$RESULT" != "value 1
value 2
value 3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should append to a list value which does not exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l "value1,value2,value3" --append -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value2
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should append to a list value which already exists"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l "value4,value5" --append -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value2
value3
value4
value5" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should prepend to a list value which does not exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l "value1,value2,value3" --prepend -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value2
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should prepend to a list value which already exists"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l "value0" --prepend -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value0
value1
value2
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should remove the first element from an existing list value"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l --remove-first -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value2
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should remove the last element from an existing list value"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l --remove-last -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should remove all elements from an existing list value"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l --remove-all -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should remove the second element from an existing list value"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l --remove-at:2 -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should remove element \"value2\" from an existing list value"

# arrange
echo "$NS|key1|value1,value2,value3|l||k1=v1" > $SOURCE_FILE

# act
./dist/relk set-key "key1" -l --remove:value2 -k k1=v1 $FLAGS
RESULT=$(./dist/relk get-key "key1" -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1
value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a template value when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key valkey1 value1 $FLAGS
./dist/relk set-key key1 -t "{valkey1}" $FLAGS
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a template value when it already exists without being forced"

# arrange
echo "$NS|valkey1|value1|s||" > $SOURCE_FILE
echo "$NS|valkey2|value2|s||" >> $SOURCE_FILE
echo "$NS|key1|{valkey1}|t||" >> $SOURCE_FILE

# act
./dist/relk set-key key1 -t "{valkey2}" $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a template value when it already exists if forced"

# arrange
echo "$NS|key1|{valkey1}|t||" > $SOURCE_FILE
echo "$NS|valkey1|value1|s||" >> $SOURCE_FILE
echo "$NS|valkey2|value2|s||" >> $SOURCE_FILE

# act
./dist/relk set-key key1 -t "{valkey2}" -f $FLAGS
RESULT=$(./dist/relk get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a template value when it already exists with different constraints"

# arrange
echo "$NS|key1|{valkey1}|t||" > $SOURCE_FILE
echo "$NS|valkey1|value1|s||" >> $SOURCE_FILE
echo "$NS|valkey2|value2|s||" >> $SOURCE_FILE

# act
./dist/relk set-key key1 -t "{valkey2}" -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a template value when it already exists with the same constraints without being forced"

# arrange
echo "$NS|key1|{valkey1}|t||k1=v1" > $SOURCE_FILE
echo "$NS|valkey1|value1|s||" >> $SOURCE_FILE
echo "$NS|valkey2|value2|s||" >> $SOURCE_FILE

# act
./dist/relk set-key key1 NEWVALUE -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a template value which contains spaces when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./dist/relk set-key "key 1" -t "value {num}" $FLAGS
RESULT=$(./dist/relk get-key "key 1" -k num=1 $FLAGS)

# assert
if [ "$RESULT" != "value 1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################

echo ""
echo "get-attributes:"

###############################################################################
TESTNAME="get-attributes should get empty attributes from an existing key-value pair"

# arrange
echo "$NS|key1|value1|s||" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-attributes "key1" $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-attributes should get attributes from an existing key-value pair"

# arrange
echo "$NS|key1|value1|s|a1=v1,a2=v2|" > $SOURCE_FILE

# act
RESULT=$(./dist/relk get-attributes "key1" $FLAGS)

# assert
if [ "$RESULT" != "a1=v1
a2=v2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-attributes should not allow command injection in attributes"

# arrange
touch /tmp/ATTR_TESTFILE
echo "" > $SOURCE_FILE

# act
./dist/relk set-key key1 -a "ttl=\$(rm /tmp/ATTR_TESTFILE)" $FLAGS
RESULT=$(./dist/relk get-attributes key1 $FLAGS)

# assert
if [ -f "/tmp/ATTR_TESTFILE" ]; then
    echo " [✓] $TESTNAME"
else
    echo " [x] $TESTNAME"
    echo "Potential vulnerability: $RESULT"
    exit 1
fi

###############################################################################

echo ""
echo "in:"

###############################################################################
TESTNAME="in should read data from stdin and evaluate the results as templates."

# arrange
TEST_FILE=/tmp/test.yaml
echo "name: {app}" > $TEST_FILE
echo "env: {env}" >> $TEST_FILE
echo "http:" >> $TEST_FILE
echo "  url: {api-url}" >> $TEST_FILE

echo "" > $SOURCE_FILE
./dist/relk set protocol "https" $FLAGS
./dist/relk set tld "myproduct.com" $FLAGS
./dist/relk set subdomain "api-dev" -k env=dev $FLAGS
./dist/relk set api-url -t "{protocol}://{subdomain}.{tld}/{app}" $FLAGS

# act
RESULT=$(cat $TEST_FILE | ./dist/relk - -k app=testapp -k env=dev $FLAGS)
RESULT1=$(echo "$RESULT" | head -n 1)
RESULT2=$(echo "$RESULT" | head -n 2 | tail -n 1)
RESULT3=$(echo "$RESULT" | head -n 3 | tail -n 1)
RESULT4=$(echo "$RESULT" | head -n 4 | tail -n 1)

# assert
if [ "$RESULT1" != "name: testapp" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT1"
    exit 1
elif [ "$RESULT2" != "env: dev" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT2"
    exit 1
elif [ "$RESULT3" != "http:" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT3"
    exit 1
elif [ "$RESULT4" != "  url: https://api-dev.myproduct.com/testapp" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT4"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="in should not do anything if stdin is not available."

# arrange
echo "" > $SOURCE_FILE

# act
RESULT=$(./dist/relk - $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result: $RESULT"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################

echo ""
echo "remove-key:"

###############################################################################
TESTNAME="remove-key should remove a key-value pair when it exists and has a subset of constraints"

# arrange
echo "" > $SOURCE_FILE
echo "$NS|key1|value6|s||k1=v3,k2=something,k3=another" >> $SOURCE_FILE
echo "$NS|key1|value5|s||k1=v3,k2=something" >> $SOURCE_FILE
echo "$NS|key1|value4|s||k1=v3" >> $SOURCE_FILE
echo "$NS|key1|value3|s||k1=v2" >> $SOURCE_FILE
echo "$NS|key1|value2|s||k1=v1" >> $SOURCE_FILE
echo "$NS|key1|value1|s||" >> $SOURCE_FILE

# act
./dist/relk remove-key key1 $FLAGS
./dist/relk remove-key key1 -k k1=v3 -k k2=something $FLAGS
RESULT1=$(./dist/relk get-key key1 -f $FLAGS)
RESULT2=$(./dist/relk get-key key1 -k k1=v1 $FLAGS)
RESULT3=$(./dist/relk get-key key1 -k k1=v2 $FLAGS)
RESULT4=$(./dist/relk get-key key1 -k k1=v3 $FLAGS)
RESULT5=$(./dist/relk get-key key1 -f -k k1=v3 -k k2=something $FLAGS)
RESULT6=$(./dist/relk get-key key1 -k k1=v3 -k k2=something -k k3=another $FLAGS)

# assert
if [ -n "$RESULT1" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 1: $RESULT1"
    exit 1
elif [ "$RESULT2" != "value2" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 2: $RESULT2"
    exit 1
elif [ "$RESULT3" != "value3" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 3: $RESULT3"
    exit 1
elif [ "$RESULT4" != "value4" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 4: $RESULT4"
    exit 1
elif [ "$RESULT5" = "value5" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 5: $RESULT5"
    exit 1
elif [ "$RESULT6" != "value6" ]; then
    echo " [x] $TESTNAME"
    echo "Unexpected result 6: $RESULT6"
    exit 1
else
    echo " [✓] $TESTNAME"
fi