#!/bin/bash

CONK_VERSION="0.1.0"

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${__dir}/conk.core.sh

# <public>
# conk set-context <...flags>
conk_cli_set_context() {
    shift 1
    result=( "$@" )
    printf '%s\n' "${result[@]}" > .conk
}

# <public>
# conk add-context <...flags>
conk_cli_add_context() {
    shift 1
    result=( "$@" )
    printf '%s\n' "${result[@]}" >> .conk
}

# <public>
# conk remove-context
conk_cli_remove_context() {
    rm -f .conk ||:
}

# <public>
# conk get-context
conk_cli_get_context() {
    context=$(conk_get_context | tr '\n' ' ')
    echo "$context"
}

# <public>
# conk get <key> (-n <namespace, -k key=value...)
conk_cli_get() {
    conk_parse_args "$@"
    conk_get_key "$KEY"
}

# <public>
# conk get-key <key> (-n <namespace, -k key=value...)
conk_cli_get_key() {
    conk_parse_args "$@"
    conk_get_key "$KEY"
}

# <public>
# conk set <key> (-n <namespace, -k key=value...)
conk_cli_set() {
    conk_parse_args "$@"
    conk_set_key
}

# <public>
# conk set-key <key> [<value>, -t <template>, -l <list....>] (-n <namespace, -k key=value...)
conk_cli_set_key() {
    conk_parse_args "$@"
    conk_set_key
}

# <public>
# conk get-keys <key> (-n <namespace, -k key=value...)
conk_cli_get_keys() {
    conk_parse_args "$@"
    conk_get_keys
}

# <public>
# conk parse <key> [<value>, -t <template>, -l <list....>] (-k key=value...)
conk_cli_parse() {
    # set up the arguments
    conk_parse_args "$@"

    echo "source: $SOURCE"
    echo "key: $KEY"
    echo "value: $VALUE"
    echo "type: $VALUE_TYPE"
    echo "namespace: $NAMESPACE"
    echo "keys:"
    printf '%s\n' "${KEYS[@]}"
}

conk_cli___version() {
    echo "$CONK_VERSION"
}

conk_cli__v() {
    conk_cli___version
}

conk_cli___help() {
    echo "Conk - Shell-based Convergent Keystore."
    echo "Version $CONK_VERSION"
    echo ""
    echo "Usage:"
    echo ""
    echo "  conk get <key> [-k <constraint_key>=<constraint_value>]... (-n <namespace>)"
    echo "    Retrieve a key-value pair based on the specified key and optional constraints."
    echo ""
    echo "  conk set <key> <value> [-k <constraint_key>=<constraint_value>]... (-n <namespace>, -f)"
    echo "    Set a key-value pair with optional constraints."
    echo ""
    echo "  conk set <key> -t <template> [-k <constraint_key>=<constraint_value>]... (-n <namespace>, -f)"
    echo "    Set a key using a template where references to other keys can be wrapped in braces."
    echo "    Optionally, you can pipe the output of a command by using {key:command}."
    echo ""
    echo "Options:"
    echo ""
    echo "  -k <constraint_key>=<constraint_value>  Set constraints for the key."
    echo "  -n <namespace>                          Specify a namespace."
    echo "  -f                                      Forces a key-value pair to be set."
    echo "  -s <provider:path>                      Sets the sourch of the conk keystore."
    echo "  --debug                                 Outputs debug messages."
    echo ""
    echo "Examples:"
    echo ""
    echo "  conk set protocol 'https'"
    echo "  conk set api-url -t '{protocol}://{host}/api'"
    echo "  conk set host 'dev.myapi.com' -k env=dev"
    echo "  conk get api-url -k env=dev"
    echo ""
    echo "For more information, see the documentation at https://github.com/stevenmhunt/conk"
}

conk_cli__h() {
    conk_cli___help
}

# <public>
conk_cli_main() {
    CMD_SUFFIX=$(echo "$1" | tr '-' '_')
    CMD="conk_cli_$CMD_SUFFIX"


    # if no command is specified:
    if [ -z "$CMD_SUFFIX" ]; then
        conk_cli___help
    # call the requested command if it exists:
    elif typeset -f $CMD > /dev/null; then
        $CMD "$@"
    else
        conk_error "Unknown command. Usage: conk <command> <...flags>"
        exit 1
    fi
}
