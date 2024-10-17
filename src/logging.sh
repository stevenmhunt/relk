################################
# Relk Logging Library
# Licensed under MIT License
################################

# <private>
# Writes debug messages to STDERR if the $DEBUG variable is set.
# parameters: 1: debug message
relk_debug() {
    if [ "$DEBUG" == "1" ]; then
        echo "[DEBUG] $1" 1>&2
    fi
}

# <private>
# Writes error messages to STDERR.
# parameters: 1: error message
relk_error() {
    echo "[ERROR] $1" 1>&2
}

# <private>
# Handles the specified error code.
# parameters: 1: error code
relk_handle_error() {
    relk_debug "Exiting with error code $1..."
    local error_code="$1"
    if [ "$error_code" == "1" ]; then
        relk_error "Unknown command. Usage: relk <command> <...flags>"
        exit 1
    elif [ "$error_code" == "2" ]; then
        relk_error "Relk platform error: invalid provider or extension."
        exit 2
    elif [ "$error_code" == "3" ]; then
        relk_error "An entry for the requested key with the same constraints already exists. Use the -f flag to overwrite this value."
        exit 3
    elif [ "$error_code" == "4" ]; then
        relk_error "No matching value could be found for the requested key with the provided constraints."
        exit 4
    elif [ "$error_code" == "5" ]; then
        relk_error "An IO error occurred when attempting to read or write to the requested source provider."
        exit 5
    elif [ "$error_code" == "6" ]; then
        relk_error "The requested key name contained invalid characters."
        exit 6
    elif [ "$error_code" == "7" ]; then
        relk_error "The requested key value contained invalid characters."
        exit 7
    else
        exit "$error_code"
    fi
}
