log() { 
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local calling_function=${FUNCNAME[1]:-"main"}
    local line_number=${BASH_LINENO[0]:-0}

    local formatted_message="[${timestamp}] [${SCRIPT_NAME}:${calling_function}:${line_number}] ${message}"
    printf "\n${formatted_message}\n" | tee -a "$LOG_FILE"
 }
