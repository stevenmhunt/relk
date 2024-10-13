#!/usr/bin/env bash

GHA_DIR=./.github/workflows

SOURCE_FILE=/tmp/.conch_ci
NS="ci"
FLAGS=(-n "$NS" -s "file:$SOURCE_FILE")
echo -n "" > "$SOURCE_FILE"
mkdir -p "$GHA_DIR"

./conch set target-platform -t "{workflow}" "${FLAGS[@]}"
./conch set job -t "{workflow}" "${FLAGS[@]}"
./conch set commands -l "" "${FLAGS[@]}"
./conch set ENV -l "FORCE_COLOR: 1" "${FLAGS[@]}"
./conch set test-command "make test" "${FLAGS[@]}"

WIN_PATHS="C:\Program Files\Git\bin;C:\windows\system32;C:\windows"
./conch set ENV -l "FORCE_COLOR: 1,PATH: '$WIN_PATHS'" -k workflow=windows-git "${FLAGS[@]}"
./conch set ENV -l "FORCE_COLOR: 1,PATH: 'C:\tools\cygwin\bin;$WIN_PATHS;C:\Windows\System32\WindowsPowerShell\v1.0;C:\ProgramData\Chocolatey\bin'" -k workflow=windows-cygwin "${FLAGS[@]}"

./conch set commands -l "brew upgrade,brew install bash" -k workflow=macos-latest "${FLAGS[@]}"
./conch set commands -l "choco install -y --no-progress cygwin cyg-get,cyg-get nc bash,cygcheck -c" -k workflow=windows-cygwin "${FLAGS[@]}"
./conch set test-command "./scripts/test.sh" -k workflow=windows-git "${FLAGS[@]}"
./conch set test-command "./scripts/test.sh" -k workflow=windows-cygwin "${FLAGS[@]}"

./conch set target-platform "windows-latest" -k workflow=windows-git "${FLAGS[@]}"

workflows="macos-latest,ubuntu-latest,windows-git,windows-cygwin"
IFS=$','
for workflow in $workflows; do
    cat ./scripts/ci_template.yml | ./conch - -k "workflow=${workflow}" "${FLAGS[@]}" > "$GHA_DIR/${workflow}.yml"
done

