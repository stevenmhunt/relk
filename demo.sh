./conch set condition-key-1 -t "{value?:some-condition = 'yes'}"
./conch set condition-key-2 -t "{value?:some-condition = 'yes' or another-key = 5}"

./conch get condition-key-1 -k value=test -k some-condition=yes
# test

./conch get condition-key-1 -k value=anothertest -k some-condition=no
# (no output)

./conch get condition-key-2 -k value=something -k another-key=5
# something