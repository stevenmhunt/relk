#!/usr/bin/env bash

GHA_DIR=./.github/workflows

SOURCE_FILE=/tmp/.conch_ci
NS="ci"
FLAGS=(-n "$NS" -s "file:$SOURCE_FILE")
echo -n "" > "$SOURCE_FILE"
mkdir -p "$GHA_DIR"

./conch set target-platform -t "{workflow}" "${FLAGS[@]}"
./conch set job -t "{workflow}" "${FLAGS[@]}"
./conch set target-platform "ubuntu-24.04" -k workflow=ubuntu-noble "${FLAGS[@]}"
./conch set target-platform "ubuntu-22.04" -k workflow=ubuntu-jammy "${FLAGS[@]}"
./conch set target-platform "ubuntu-20.04" -k workflow=ubuntu-focal "${FLAGS[@]}"

workflows="ubuntu-noble,ubuntu-jammy,ubuntu-focal"
IFS=$','
for workflow in $workflows; do
    cat ./scripts/ci_template.yml | ./conch - -k "workflow=${workflow}" "${FLAGS[@]}" > "$GHA_DIR/${workflow}.yml"
done

