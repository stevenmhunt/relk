################################
# Relk Platform Library
# Licensed under MIT License
################################

# <private>
# Calls the specified provider command function.
# parameters 1: provider, 2: command, ...arguments
relk_platform_provider_call() {
    local command="relk_platform_provider_$1_$2"

    if typeset -f $command > /dev/null; then
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

    if typeset -f $command > /dev/null; then
        $command "${@:3}" || relk_handle_error "$?"
    else
        relk_handle_error "2"
    fi
}

# <private>
# Calls the hook function for each extension.
# parameters 1: extensions, 2: hook, ...arguments
relk_platform_extensions_call() {
    local extensions="$1"
    local hook="$2"
    shift 2
    local args=("$@")    

    for extension in $extensions; do
        relk_platform_extension_call "$extension" "$hook" "${args[@]}"
    done
}