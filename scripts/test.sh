#!/usr/bin/env bash

SOURCE_FILE=/tmp/.conchfile
NS="testrun"
FLAGS="-n $NS -s file:$SOURCE_FILE"

echo "Conch Test Script 🐚"

###############################################################################

echo ""
echo "get-keys:"

###############################################################################
TESTNAME="get-keys should return nothing when there are no keys"

# arrange
echo "" > $SOURCE_FILE

# act
RESULT=$(./conch get-keys $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-keys should return keys when there are keys"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE

# act
RESULT=$(./conch get-keys $FLAGS)

# assert
if [ "$RESULT" != "key1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
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
RESULT=$(./conch get-key key1 $FLAGS 2>&1)

# assert
if [ "$?" -eq 0 ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE

# act
RESULT=$(./conch get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an empty key value when it exists"

# arrange
echo "$NS|key1||s|" > $SOURCE_FILE

# act
RESULT=$(./conch get-key key1 $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists and has constraints"

# arrange
echo "" > $SOURCE_FILE
echo "$NS|key1|valuedev|s|env=dev" >> $SOURCE_FILE
echo "$NS|key1|valuetest|s|env=test" >> $SOURCE_FILE
echo "$NS|key1|valueprod|s|env=prod" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key1 -k env=dev $FLAGS)

# assert
if [ "$RESULT" != "valuedev" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should not return key value when it exists but has constraints that don't match"

# arrange
echo "" > $SOURCE_FILE
echo "$NS|key1|valuedev|s|env=dev" >> $SOURCE_FILE
echo "$NS|key1|valuetest|s|env=test" >> $SOURCE_FILE
echo "$NS|key1|valueprod|s|env=prod" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key1 -k env=invalid $FLAGS 2>&1)

# assert
if [ "$?" -eq 0 ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists and requested constraints do not apply"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE

# act
RESULT=$(./conch get-key key1 -k env=dev $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return key value when it exists and has a subset of constraints"

# arrange
echo "" > $SOURCE_FILE
echo "$NS|key1|value6|s|k1=v3,k2=something,k3=another" >> $SOURCE_FILE
echo "$NS|key1|value5|s|k1=v3,k2=something" >> $SOURCE_FILE
echo "$NS|key1|value4|s|k1=v3" >> $SOURCE_FILE
echo "$NS|key1|value3|s|k1=v2" >> $SOURCE_FILE
echo "$NS|key1|value2|s|k1=v1" >> $SOURCE_FILE
echo "$NS|key1|value1|s|" >> $SOURCE_FILE

# act
RESULT1=$(./conch get-key key1 $FLAGS)
RESULT2=$(./conch get-key key1 -k k1=v1 $FLAGS)
RESULT3=$(./conch get-key key1 -k k1=v2 $FLAGS)
RESULT4=$(./conch get-key key1 -k k1=v3 $FLAGS)
RESULT5=$(./conch get-key key1 -k k1=v3 -k k2=something $FLAGS)
RESULT6=$(./conch get-key key1 -k k1=v3 -k k2=something -k k3=another $FLAGS)

# assert
if [ "$RESULT1" != "value1" ]; then
    echo "Unexpected result 1: $RESULT1"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT2" != "value2" ]; then
    echo "Unexpected result 2: $RESULT2"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT3" != "value3" ]; then
    echo "Unexpected result 3: $RESULT3"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT4" != "value4" ]; then
    echo "Unexpected result 4: $RESULT4"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT5" != "value5" ]; then
    echo "Unexpected result 5: $RESULT5"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT6" != "value6" ]; then
    echo "Unexpected result 6: $RESULT6"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value when it exists"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE
echo "$NS|key2|{key1}|t|" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key2 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template with an empty value when it exists"

# arrange
echo "$NS|key1||s|" > $SOURCE_FILE
echo "$NS|key2|{key1}|t|" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key2 $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value when it exists with constraints"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE
echo "$NS|key1|value2|s|k1=v1" >> $SOURCE_FILE
echo "$NS|key2|{key1}|t|" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key2 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value2" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value with mulitple references when it exists with constraints"

# arrange
echo "$NS|key1|value0|s|" > $SOURCE_FILE
echo "$NS|key1|value1|s|k1=v1" >> $SOURCE_FILE
echo "$NS|key2|value2|s|k1=v1" >> $SOURCE_FILE
echo "$NS|key3|value3|s|k1=v1" >> $SOURCE_FILE
echo "$NS|key4|{key1}{key2}{key3}|t|" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key4 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1value2value3" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should return an evaluated template value within a template value when it exists with constraints"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE
echo "$NS|key1|value2|s|k1=v1" >> $SOURCE_FILE
echo "$NS|key2|{key1}|t|" >> $SOURCE_FILE
echo "$NS|key3|{key2}|t|" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key3 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value2" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="get-key should handle cycle detection resolution gracefully"

# arrange
echo "$NS|key1|{key2}|t|" > $SOURCE_FILE
echo "$NS|key2|{key1}|t|" >> $SOURCE_FILE

# act
RESULT=$(./conch get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################

echo ""
echo "set-key:"

###############################################################################
TESTNAME="set-key should set a key value when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./conch set-key key1 value1 $FLAGS
RESULT=$(./conch get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a key value when it already exists without being forced"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE

# act
./conch set-key key1 NEWVALUE $FLAGS &> /dev/null
RESULT=$(./conch get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a key value when it already exists if forced"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE

# act
./conch set-key key1 NEWVALUE -f $FLAGS &> /dev/null
RESULT=$(./conch get-key key1 $FLAGS)

# assert
if [ "$RESULT" != "NEWVALUE" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a key value when it already exists with different constraints"

# arrange
echo "$NS|key1|value1|s|" > $SOURCE_FILE

# act
./conch set-key key1 NEWVALUE -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./conch get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "NEWVALUE" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should not set a key value when it already exists with the same constraints without being forced"

# arrange
echo "$NS|key1|value1|s|k1=v1" > $SOURCE_FILE

# act
./conch set-key key1 NEWVALUE -k k1=v1 $FLAGS &> /dev/null
RESULT=$(./conch get-key key1 -k k1=v1 $FLAGS)

# assert
if [ "$RESULT" != "value1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="set-key should set a key value which contains spaces when it doesn't exist"

# arrange
echo "" > $SOURCE_FILE

# act
./conch set-key "key 1" "value 1" $FLAGS
RESULT=$(./conch get-key "key 1" $FLAGS)

# assert
if [ "$RESULT" != "value 1" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
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
./conch set protocol "https" $FLAGS
./conch set tld "myproduct.com" $FLAGS
./conch set subdomain "api-dev" -k env=dev $FLAGS
./conch set api-url -t "{protocol}://{subdomain}.{tld}/{app}" $FLAGS

# act
RESULT=$(cat $TEST_FILE | ./conch - -k app=testapp -k env=dev $FLAGS)
RESULT1=$(echo "$RESULT" | head -n 1)
RESULT2=$(echo "$RESULT" | head -n 2 | tail -n 1)
RESULT3=$(echo "$RESULT" | head -n 3 | tail -n 1)
RESULT4=$(echo "$RESULT" | head -n 4 | tail -n 1)

# assert
if [ "$RESULT1" != "name: testapp" ]; then
    echo "Unexpected result: $RESULT1"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT2" != "env: dev" ]; then
    echo "Unexpected result: $RESULT1"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT3" != "http:" ]; then
    echo "Unexpected result: $RESULT1"
    echo " [x] $TESTNAME"
    exit 1
elif [ "$RESULT4" != "  url: https://api-dev.myproduct.com/testapp" ]; then
    echo "Unexpected result: $RESULT1"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi

###############################################################################
TESTNAME="in should not do anything if stdin is not available."

# arrange
echo "" > $SOURCE_FILE

# act
RESULT=$(./conch - $FLAGS)

# assert
if [ -n "$RESULT" ]; then
    echo "Unexpected result: $RESULT"
    echo " [x] $TESTNAME"
    exit 1
else
    echo " [✓] $TESTNAME"
fi