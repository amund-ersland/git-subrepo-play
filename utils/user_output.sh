LINE="\n$(for i in $(seq 1 80); do printf '='; done)"

#===============================================================================
run() {
    echo "$*" | tee -a "$CMD_LOG"
    {
        echo
        echo "$ $*"

        "$@"
        rc=$?

        if [[ $rc -ne 0 ]]; then
            echo "[exit code: $rc]"
        fi

    } >> "$FULL_LOG" 2>&1

    return $rc
}


#===============================================================================
INFO(){
    LOG_INFO "$1"
    STDOUT_INFO "$1"
}

#===============================================================================
LOG_INFO(){
    printf "\n\033[35m$1\033[0m" >> $CMD_LOG
    printf "\n\033[35m$1\033[0m" >> $FULL_LOG
}

#===============================================================================
STDOUT_INFO(){
    echo -e "\033[35m$1\033[0m"
}

#===============================================================================
TEXT(){
    LOG_TEXT "$1"
    STDOUT_TEXT "$1"
}

#===============================================================================
LOG_TEXT(){
    printf "\n$1" >> $CMD_LOG
    printf "\n$1" >> $FULL_LOG
}

#===============================================================================
STDOUT_TEXT(){
    echo -e "$1"
}

#===============================================================================
# Call at the top of each scenario script: parse_args "$@"
parse_args(){
    SKIP_PAUSE=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--skip-pause) SKIP_PAUSE=true; shift ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done
}

#===============================================================================
# TITLE introduces a scenario. It clears the screen, prints the overview and
# waits for the user to start. It also resets the step counter so the first
# STEP does not wait for a (non-existent) previous step.
# Pass -s / --skip-pause to a scenario script to run non-interactively.
TITLE(){
    _STEP_STARTED=false
    [[ "${SKIP_PAUSE:-false}" != "true" ]] && clear
    STDOUT_INFO "🥬 $1"
    if [[ "${SKIP_PAUSE:-false}" != "true" ]]; then
        read -p "↵  press enter to start..."
    fi
}

#===============================================================================
# STEP is the primary interaction primitive for scenarios. Every step:
#   1. waits for the user to finish reading the PREVIOUS step's output
#      (skipped for the very first step after a TITLE)
#   2. clears the terminal
#   3. prints what this step is about to do
#   4. waits for the user to press enter before the commands below it run
#
# So the commands and their status output always appear directly under the
# description of what they do, and the user is in control of the pace.
# Pass -s / --skip-pause to a scenario script to run non-interactively.
STEP(){
    local msg=$1

    # 1. In interactive mode: let the user review the previous step, then wipe
    #    the screen. Skipped entirely with --skip-pause so output stays scrolled.
    if [[ "${SKIP_PAUSE:-false}" != "true" ]]; then
        [[ "${_STEP_STARTED:-false}" == "true" ]] && read -p "↵  press enter for the next step..."
        clear
    fi
    _STEP_STARTED=true

    # 2. Announce what is about to happen.
    # Logs may not exist yet on the very first (setup) step, so fall back to
    # stdout-only until CMD_LOG/FULL_LOG have been created.
    if [[ -n "${CMD_LOG:-}" ]]; then
        INFO "💡 $msg"
    else
        STDOUT_INFO "💡 $msg"
    fi

    # 3. Wait for the go-ahead, then the caller's commands run.
    if [[ "${SKIP_PAUSE:-false}" != "true" ]]; then
        read -p "↵  press enter to run this step..."
        echo
    fi
}

#===============================================================================
ERROR(){
    LOG_ERROR "$1"
    STDOUT_ERROR "$1"
}

#===============================================================================
LOG_ERROR(){
    printf "\n\033[31m$1\033[0m" >> $CMD_LOG
    printf "\n\033[31m$1\033[0m" >> $FULL_LOG
}

#===============================================================================
STDOUT_ERROR(){
    echo -e "\033[31m$1\033[0m"
}
