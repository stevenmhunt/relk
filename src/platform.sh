################################
# Relk Platform Library
# Licensed under MIT License
################################

# <private>
# Calls the specified provider command function.
# parameters 1: provider, 2: command, ...arguments
relk_platform_provider_call() {
    local command="relk_platform_provider_$1_$2"

    if type $command &>/dev/null; then
        $command "${@:3}" || relk_handle_error "$?"
    else
        relk_handle_error "2"
    fi
}

# <private>
# Calls the specified extension hook function.
# parameters 1: extension, 2: hook, ...arguments
relk_platform_extension_call() {
    local command="relk_platform_extension_$1_$2"
    relk_debug "platform_extension_call() command: $command"

    if type $command &> /dev/null; then
        $command "${@:3}" || relk_handle_error "$?"
    else
        exit 2
    fi
}

# <private>
# Calls the hook function for each extension.
# parameters 1: hook, 2: change value, ...arguments
relk_platform_hook() {
    local hook="$1"
    local change="$2"

    while IFS= read -r extension || [[ -n "$extension" ]]; do
        if [ -n "$extension" ]; then
            change=$((relk_platform_extension_call "$extension" "$hook" "$change" "${@:3}") || echo "$change")
        fi
    done <<< "$EXTENSIONS"

    echo "$change"
}
