#!/bin/bash

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

# <public>
conk_cli_main() {
    CMD_SUFFIX=$(echo "$1" | tr '-' '_')
    CMD="conk_cli_$CMD_SUFFIX"

    # call the requested command if it exists.
    if typeset -f $CMD > /dev/null; then
        $CMD "$@"
    else
        conk_error "Unknown command. Usage: conk <command> <...flags>"
        exit 1
    fi
}
