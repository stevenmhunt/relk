#!/usr/bin/env bash
# Conch CLI Commands
# Licensed under MIT License

CONCH_VERSION="0.3.0"

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${__dir}/conch.core.sh

# conch set-context <...flags>
conch_cli_set_context() {
    shift 1
    local context=( "$@" )
    printf '%s\n' "${context[@]}" > .conch
}

# conch add-context <...flags>
conch_cli_add_context() {
    shift 1
    local context=( "$@" )
    printf '%s\n' "${context[@]}" >> .conch
}

# conch remove-context
conch_cli_remove_context() {
    rm -f .conch ||:
}

# conch get-context
conch_cli_get_context() {
    conch_get_context | tr '\n' ' '
}

# conch get <key> (-n <namespace, -k key=value...)
conch_cli_get() {
    conch_parse_key_args "$@"
    conch_get_key "$KEY" "$FORCE_READ"
}

# conch get-key <key> (-n <namespace, -k key=value...)
conch_cli_get_key() {
    conch_parse_key_args "$@"
    conch_get_key "$KEY" "$FORCE_READ"
}

# conch set <key> [<value>, -t <template>, -l <list....>] (-n <namespace, -k key=value...)
conch_cli_set() {
    conch_parse_key_args "$@"
    conch_set_key
}

# conch set-key <key> [<value>, -t <template>, -l <list....>] (-n <namespace, -k key=value...)
conch_cli_set_key() {
    conch_parse_key_args "$@"
    conch_set_key
}

# conch get-keys (-n <namespace, -k key=value...)
conch_cli_get_keys() {
    conch_parse_args "$@"
    conch_get_keys
}

# conch in (-n <namespace, -k key=value...)
conch_cli_in() {
    conch_parse_args "$@"
    conch_in
}

# conch - (-n <namespace, -k key=value...)
conch_cli__() {
    conch_parse_args "$@"
    conch_in
}

# conch --version
conch_cli___version() {
    echo "$CONCH_VERSION"
}

# conch -v
conch_cli__v() {
    conch_cli___version
}

# conch --help
conch_cli___help() {
    echo "Conch 🐚 - Relational Key-Value Store"
    echo "Version $CONCH_VERSION"
    echo ""
    cat "${__dir}/usage.txt" | envsubst
}

# conch -h
conch_cli__h() {
    conch_cli___help
}

# conch <command> <args...>
conch_main() {
    local command_suffix=$(echo "$1" | tr '-' '_')
    local command="conch_cli_$command_suffix"

    # if no command is specified:
    if [ -z "$command_suffix" ]; then
        conch_cli___help
    # call the requested command if it exists:
    elif typeset -f $command > /dev/null; then
        $command "$@"
    else
        conch_handle_error "1"
    fi
}
