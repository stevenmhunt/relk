################################
# Relk Platform Library
# Licensed under MIT License
################################

# <private>
# Calls the specified provider command function.
# parameters 1: provider, 2: command, ...arguments
relk_platform_provider_call() {
    local command="relk_platform_provider_$1_$2"
    if [[ "$command" =~ \ |\' ]]; then
            relk_handle_error "2"
    elif type $command &>/dev/null; then
        $command "${@:3}" || relk_handle_error "$?"
    else
        relk_handle_error "2"
    fi
}

# <private>
# Calls the specified extension hook function.
# parameters 1: extension, 2: hook, ...arguments
relk_platform_extension_call() {
    # don't try to call extensions if none are loaded.
    if [ -z "$EXTENSIONS" ]; then
        return
    fi

    local command="relk_platform_extension_$1_$2"
    if [[ "$command" =~ \ |\' ]]; then
        exit 2
    elif type $command &> /dev/null; then
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

    # don't try to call extensions if none are loaded.
    if [ -z "$EXTENSIONS" ]; then
        echo "$change"
        return
    fi

    # load depdendencies
    local extensions="$EXTENSIONS"
    while :; do
        local new_items_found=false
        extensions=$(echo "$extensions" | sort -u)
        while IFS= read -r extension || [[ -n "$extension" ]]; do
            if [ -n "$extension" ]; then
                local results
                local dependencies=$((relk_platform_extension_call "$extension" 'get_extensions') || echo "")
                results=$(echo -e "$dependencies" | grep -vFx "$(echo -e "$extensions")")
                if [ -n "$results" ]; then
                    new_items_found=true
                    extensions+="
$results"
                fi
            fi
        done <<< "$extensions"

        if ! $new_items_found; then
            break
        fi
    done

    # attempt to call platfrom hook for each loaded extension.
    while IFS= read -r extension || [[ -n "$extension" ]]; do
        if [ -n "$extension" ]; then
            change=$((relk_platform_extension_call "$extension" "$hook" "$change" "${@:3}") || echo "$change")
        fi
    done <<< "$extensions"

    echo "$change"
}
