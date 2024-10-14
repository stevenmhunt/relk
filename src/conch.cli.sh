#!/usr/bin/env bash
# Conch CLI Commands
# Licensed under MIT License

CONCH_VERSION="0.2.0"

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
    conch_get_key "$KEY"
}

# conch get-key <key> (-n <namespace, -k key=value...)
conch_cli_get_key() {
    conch_parse_key_args "$@"
    conch_get_key "$KEY"
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
    echo "Conch - Shell-based Convergent Keystore."
    echo "Version $CONCH_VERSION"
    echo ""
    echo "Usage:"
    echo ""
    echo "  conch get <key> [-k <constraint_key>=<constraint_value>]... (-n <namespace>)"
    echo "    Retrieve a key-value pair based on the specified key and optional constraints."
    echo ""
    echo "  conch set <key> <value> [-k <constraint_key>=<constraint_value>]... (-n <namespace>, -f)"
    echo "    Set a key-value pair with optional constraints."
    echo ""
    echo "  conch set <key> -t <template> [-k <constraint_key>=<constraint_value>]... (-n <namespace>, -f)"
    echo "    Set a key using a template where references to other keys can be wrapped in braces."
    echo "    Optionally, you can pipe the output of a command by using {key:command}."
    echo ""
    echo "Options:"
    echo ""
    echo "  -k <constraint_key>=<constraint_value>  Set constraints for the key."
    echo "  -n <namespace>                          Specify a namespace."
    echo "  -f                                      Forces a key-value pair to be set."
    echo "  -s <provider:path>                      Sets the sourch of the conch keystore."
    echo "  --debug                                 Outputs debug messages."
    echo ""
    echo "Examples:"
    echo ""
    echo "  conch set protocol 'https'"
    echo "  conch set api-url -t '{protocol}://{host}/api'"
    echo "  conch set host 'dev.myapi.com' -k env=dev"
    echo "  conch get api-url -k env=dev"
    echo ""
    echo "For more information, see the documentation at https://github.com/stevenmhunt/conch"
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
