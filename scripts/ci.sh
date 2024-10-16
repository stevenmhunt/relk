#!/usr/bin/env bash

GHA_DIR=./.github/workflows

SOURCE_FILE=/tmp/.relk_ci
NS="ci"
FLAGS=(-n "$NS" -s "file:$SOURCE_FILE")
echo -n "" > "$SOURCE_FILE"
mkdir -p "$GHA_DIR"

./relk set target-platform -t "{workflow}" "${FLAGS[@]}"
./relk set job -t "{workflow}" "${FLAGS[@]}"
./relk set commands -l "" "${FLAGS[@]}"
./relk set ENV -l "FORCE_COLOR: 1" "${FLAGS[@]}"
./relk set test-command "make test" "${FLAGS[@]}"

WIN_PATHS="C:\Program Files\Git\bin;C:\windows\system32;C:\windows"
./relk set ENV -l "FORCE_COLOR: 1,PATH: '$WIN_PATHS'" -k workflow=windows-git "${FLAGS[@]}"
./relk set ENV -l "FORCE_COLOR: 1,PATH: 'C:\tools\cygwin\bin;$WIN_PATHS;C:\Windows\System32\WindowsPowerShell\v1.0;C:\ProgramData\Chocolatey\bin'" -k workflow=windows-cygwin "${FLAGS[@]}"

./relk set commands -l "brew upgrade,brew install bash" -k workflow=macos-latest "${FLAGS[@]}"
./relk set commands -l "choco install -y --no-progress cygwin cyg-get,cyg-get nc bash,cygcheck -c" -k workflow=windows-cygwin "${FLAGS[@]}"
./relk set test-command "./scripts/test.sh" -k workflow=windows-git "${FLAGS[@]}"
./relk set test-command "./scripts/test.sh" -k workflow=windows-cygwin "${FLAGS[@]}"

./relk set target-platform "windows-latest" -k workflow=windows-git "${FLAGS[@]}"
./relk set target-platform "windows-latest" -k workflow=windows-cygwin "${FLAGS[@]}"

workflows="macos-latest,ubuntu-latest,windows-git"
IFS=$','
for workflow in $workflows; do
    cat ./scripts/ci_template.yml | ./relk - -k "workflow=${workflow}" "${FLAGS[@]}" > "$GHA_DIR/${workflow}.yml"
done

