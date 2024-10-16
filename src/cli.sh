################################
# Relk CLI Commands
# Licensed under MIT License
################################

RELK_VERSION="0.4.0"

# relk set-context <...flags>
relk_cli_set_context() {
    shift 1
    local context=( "$@" )
    printf '%s\n' "${context[@]}" > .relk
}

# relk add-context <...flags>
relk_cli_add_context() {
    shift 1
    local context=( "$@" )
    printf '%s\n' "${context[@]}" >> .relk
}

# relk remove-context
relk_cli_remove_context() {
    rm -f .relk ||:
}

# relk get-context
relk_cli_get_context() {
    relk_get_context | tr '\n' ' '
}

# relk get <key> (-n <namespace, -k key=value...)
relk_cli_get() {
    relk_parse_key_args "$@"
    relk_get_key "$KEY" "$FORCE_READ"
}

# relk get-key <key> (-n <namespace, -k key=value...)
relk_cli_get_key() {
    relk_parse_key_args "$@"
    relk_get_key "$KEY" "$FORCE_READ"
}

# relk set <key> [<value>, -t <template>, -l <list....>] (-n <namespace, -k key=value...)
relk_cli_set() {
    relk_parse_key_args "$@"
    relk_set_key
}

# relk set-key <key> [<value>, -t <template>, -l <list....>] (-n <namespace, -k key=value...)
relk_cli_set_key() {
    relk_parse_key_args "$@"
    relk_set_key
}

# relk get-keys (-n <namespace, -k key=value...)
relk_cli_get_keys() {
    relk_parse_args "$@"
    relk_get_keys
}

# relk in (-n <namespace, -k key=value...)
relk_cli_in() {
    relk_parse_args "$@"
    relk_in
}

# relk - (-n <namespace, -k key=value...)
relk_cli__() {
    relk_parse_args "$@"
    relk_in
}

# relk --version
relk_cli___version() {
    echo "$RELK_VERSION"
}

# relk -v
relk_cli__v() {
    relk_cli___version
}

# relk --help
relk_cli___help() {
    echo "Relk - Relational Key Store"
    echo "Version $RELK_VERSION"
    echo ""
    cat "${RELK_SHARED}/usage.txt" | envsubst
}

# relk -h
relk_cli__h() {
    relk_cli___help
}

# relk <command> <args...>
relk_main() {
    local command_suffix=$(echo "$1" | tr '-' '_')
    local command="relk_cli_$command_suffix"

    # if no command is specified:
    if [ -z "$command_suffix" ]; then
        relk_cli___help
    # call the requested command if it exists:
    elif typeset -f $command > /dev/null; then
        $command "$@"
    else
        relk_handle_error "1"
    fi
}