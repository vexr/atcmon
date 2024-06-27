#!/bin/bash

# Function to check if a package is installed
function app::dependencies:check() {
    local package="$1"
    if command -v "$package" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to install a package using apt
function install_package_apt() {
    local package="$1"
    printf "Installing %s using apt...\n" "$package"
    sudo apt update
    sudo apt install -y "$package"
}

# Function to install a package using yum
function install_package_yum() {
    local package="$1"
    printf "Installing %s using yum...\n" "$package"
    sudo yum install -y epel-release
    sudo yum install -y "$package"
}

# Function to install packages based on package manager
function install_package() {
    local package="$1"
    if command -v apt &> /dev/null; then
        install_package_apt "$package"
    elif command -v yum &> /dev/null; then
        install_package_yum "$package"
    else
        printf "Neither apt nor yum package manager found. Please install %s manually.\n" "$package"
        exit 1
    fi
}

# Main script to check and install packages
function app::dependencies() {
    local package="$1"
    if app::dependencies:check "$package"; then
        return 0
    else
        printf "The system will install %s.\n" "$package"
        install_package "$package"
    fi

    # Verify installation
    if app::dependencies:check "$package"; then
        printf "%s has been successfully installed.\n" "$package"
    else
        printf "Failed to install %s.\n" "$package"
        exit 1
    fi
}




# Set script colors
C_BRIGHT_BLUE="\e[94m"
C_BRIGHT_GREEN="\e[92m" # Unused, but included for reference

C_FRAME="$C_BRIGHT_BLUE"        # Frame color
C_BOLD="\e[1m"                  # Bold text
C_RESET="\e[0m"                 # Reset color
SPACER="${C_FRAME}│${C_RESET}"  # Spacer used in the frame


function app::set::global:vars() {
    app_path="$(cd "$(dirname "$0")" && pwd)"
    app_config=$(jq -c '.' "$app_path/config.json")
}


message::info() {
    local message="$1"
    printf "\e[34m%s\e[0m\n" "$message"
}


function app::init::config() {
    clear

    stty -echo # Disable echoing
    tput civis # Hide cursor

    message::info " Initializing atcmon, please wait..."

    parse_json() {
        local section_names=($(jq -r 'keys[]' <<< "$app_config"))

        for section_name in "${section_names[@]}"; do
            local inner_object
            # Extract the inner object with dynamic key names
            inner_object=$(jq ".$section_name" <<< "$app_config")

            while IFS="=" read -r key value; do
                if [ ! -z "$key" ]; then
                    local variable_name
                    variable_name=$(sanitize_variable_name "${key//\"/}")
                    # Prepend variable name with the section name and an underscore
                    local variable_prefix="${section_name}_"
                    local config_variable_name="${variable_prefix}${variable_name}"
                    local variable_value
                    variable_value=$(jq -r ".$key" <<< "$inner_object")

                    # Check if the value is an array
                    if jq -e ".${section_name}.${key} | type == \"array\"" <<< "$app_config" > /dev/null; then
                        # If it's an array, read it into an indexed array
                        readarray -t "${config_variable_name}" < <(jq -r ".${section_name}.${key}[]" <<< "$app_config")
                    else
                        # If it's not an array, treat it as a string and assign it to a variable
                        printf -v "$config_variable_name" "%s" "$variable_value"
                    fi
                fi
            done < <(jq -r 'to_entries[] | "\(.key)=\(.value | tostring)"' <<< "$inner_object")
        done
    }

    sanitize_variable_name() {
        local name="$1"
        # Replace characters other than alphanumeric and underscore with underscore
        name="${name//[^[:alnum:]_]/_}"
        printf "%s" "$name"
    }

    # Parse config.json file to set variables
    parse_json

    tput cnorm # Restore cursor
    stty echo # Enable echoing
}


function format::align() {
    local text="$1"
    local alignment="$2"
    local length=${#text}
    local total_width="${3:-13}"

    local free_blank_spaces=$((total_width - length))
    local left_padding=0 right_padding=0

    case "$alignment" in
        l) right_padding=$free_blank_spaces;;
        r) left_padding=$free_blank_spaces;;
        c) if ((free_blank_spaces % 2 != 0)); then
               left_padding=$((free_blank_spaces / 2))
           else
               left_padding=$((free_blank_spaces / 2))
           fi
           ;;
    esac

    printf "%*s%s%*s" $left_padding '' "$text" $right_padding ''
}


# Format numbers for dashboard display
function format::number() {
    local number="$1"
    local precision="${2:-2}"
    local suffix="$3"

    # If the number is zero and suffix is "incomplete_check" then format status to avoid divide by zero calculations
    if [[ $number == "0" ]] && [[ $suffix == "incomplete_check" ]]; then
        printf "%s" "-"
        return
    fi

    # If the number is zero then display a dash
    if [[ $number == "0" ]]; then
        printf "%s" "-"
        return
    fi

    # Strip any leading zeros from the number
    number=$(sed 's/^0*//' <<< "$number")

    # Format the number with comma digit grouping and precision if the number is a float
    if [[ $number =~ \. ]]; then
        # Add thousands separator and format the number to the specified precision
        local formatted_number=$(printf "%'.${precision}f" "$number" | sed -E ':a;s/([0-9])([0-9]{3})([.,])/\1,\2\3/;ta')
    else
        # Add thousands separator to the number
        local formatted_number=$(printf "%'d" "$number" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')
    fi

    # Add suffix to the number if provided
    if [[ -n $suffix ]]; then
        if [[ $suffix == "%" ]]; then
            printf "%s%s\n" "$formatted_number" "$suffix"
        else
            printf "%s %s\n" "$formatted_number" "$suffix"
        fi
    else
        printf "%s\n" "$formatted_number"
    fi
}


function format::time() {
    # Format status if time is zero
    if [[ "$1" == "0" || -z "$1" ]]; then
        printf "%s" "-"
        return
    fi

    local precision="${2:-0}"

    local total_seconds="$1"
    local days=$(echo "scale=0; $total_seconds / 86400" | bc)
    local hours=$(echo "scale=0; ($total_seconds % 86400) / 3600" | bc)
    local minutes=$(echo "scale=0; ($total_seconds % 3600) / 60" | bc)
    local seconds=$(echo "scale=0; ($total_seconds % 3600) % 60" | bc)

    if (( days > 0 )); then # View for time greater than 1 day
        printf "%dd %dh\n" "$days" "$hours"
    elif (( hours > 0 )); then # View for time in hours
        printf "%dh %dm\n" "$hours" "$minutes"
    elif (( minutes > 0 )); then # View for time in minutes
        printf "%02d:%02.0f\n" "$minutes" "$seconds"
    else # View for only seconds
        printf "%.${precision}fs\n" "$seconds"
    fi
}


function monitor::pull:reward:metrics() {
    trap 'exit_module=true' SIGINT

    # Define search terms and corresponding prefixes
    local term_claimed_block="Claimed block"
    local term_claimed_vote="Claimed vote"
    local term_claimed_bundle="Claimed bundle"
    local term_error_expired="Sector expired"
    local term_error_too_slow="Solution was ignored, likely because farmer was too slow"
    local term_error_farming_time_limit="Proving for solution skipped due to farming time limit slot"

    declare -A term_prefix_mapping=(
        ["term_claimed_block"]="block"
        ["term_claimed_vote"]="vote"
        ["term_claimed_bundle"]="bundle"
        ["term_error_expired"]="expired"
        ["term_error_too_slow"]="slow"
        ["term_error_farming_time_limit"]="slow"
    )

    # Define and convert common time parameters in log file timestamp format to seconds
    reward_period_1_seconds=$(date --date="${period_reward_period_1} ago" -u +"%s")
    reward_period_2_seconds=$(date --date="${period_reward_period_2} ago" -u +"%s")
    reward_period_3_seconds=$(date --date="${period_reward_period_3} ago" -u +"%s")
    reward_period_4_seconds=$(date --date="${period_reward_period_4} ago" -u +"%s")

    # Run each search term and process timestamps
    for term in "${!term_prefix_mapping[@]}"; do
        wins_variable_prefix="${term_prefix_mapping[$term]}"
        wins_period_1=0 wins_period_2=0 wins_period_3=0 wins_period_4=0

        for log_file in "${config_farmer_log}" "${config_node_log}"; do
            if [[ -f "$log_file" && -s "$log_file" ]]; then
                while IFS= read -r log_entry; do
                    IFS=' ' read -r timestamp rest <<< "$log_entry"
                    timestamp_seconds=$(date --date="${timestamp}" -u +"%s")

                    ((timestamp_seconds < reward_period_4_seconds)) && break
                    ((timestamp_seconds >= reward_period_1_seconds)) && ((wins_period_1++))
                    ((timestamp_seconds >= reward_period_2_seconds)) && ((wins_period_2++))
                    ((timestamp_seconds >= reward_period_3_seconds)) && ((wins_period_3++))
                    ((timestamp_seconds >= reward_period_4_seconds && timestamp_seconds < reward_period_3_seconds)) && ((wins_period_4++))
                done < <(grep -aF "${!term}" "${log_file}" | tac)
            fi
        done


        # Assign the results to the corresponding variables
        printf -v "${wins_variable_prefix}_period_1" "%s" "${wins_period_1}"
        printf -v "${wins_variable_prefix}_period_2" "%s" "${wins_period_2}"
        printf -v "${wins_variable_prefix}_period_3" "%s" "${wins_period_3}"
        printf -v "${wins_variable_prefix}_period_4" "%s" "${wins_period_4}"
    done

    # Correctly format bundles if there are none for that time duration
    for duration in period_1 period_2 period_3 period_4; do
        bundle_var="bundle_${duration}"

        if (( ${!bundle_var} == 0 )); then
            printf -v "${bundle_var}" "%s" "-"
        fi
    done

    declare -A formatted_vote_block formatted_slow formatted_expired total_block_vote

    # Calculate total block votes for each period
    for duration in period_1 period_2 period_3 period_4; do
        vote_var="vote_${duration}"
        block_var="block_${duration}"
        slow_var="slow_${duration}"
        expired_var="expired_${duration}"
        total_block_vote_var="total_block_vote_${duration}"

        formatted_block[$duration]=$(format::number "${!block_var}" 0)
        formatted_vote[$duration]=$(format::number "${!vote_var}" 0)
        formatted_block_vote_total[$duration]=$(format::number "$(( ${!block_var} + ${!vote_var} ))" 0)
        formatted_slow[$duration]=$(format::number "${!slow_var}" 0)
        formatted_expired[$duration]=$(format::number "${!expired_var}" 0)

        if ((${!vote_var} + ${!block_var} != 0)); then
            formatted_slow_percent[$duration]=$(format::number "$(echo "scale=2; (${!slow_var} * 100) / (${!vote_var} + ${!block_var} + ${!slow_var} + ${!expired_var})" | bc)" 1 "%")
            formatted_expired_percent[$duration]=$(format::number "$(echo "scale=2; (${!expired_var} * 100) / (${!vote_var} + ${!block_var} + ${!slow_var} + ${!expired_var})" | bc)" 1 "%")
        else
            formatted_slow_percent[$duration]="-"
            formatted_expired_percent[$duration]="-"
        fi

        printf -v "formatted_vote_block_${duration}" "%s" "${formatted_vote_block[$duration]}"
        printf -v "formatted_block_${duration}" "%s" "${formatted_block[$duration]}"
        printf -v "formatted_vote_${duration}" "%s" "${formatted_vote[$duration]}"
        printf -v "formatted_block_vote_total_${duration}" "%s" "${formatted_block_vote_total[$duration]}"
        printf -v "formatted_slow_${duration}" "%s" "${formatted_slow[$duration]}"
        printf -v "formatted_slow_percent_${duration}" "%s" "${formatted_slow_percent[$duration]}"
        printf -v "formatted_expired_${duration}" "%s" "${formatted_expired[$duration]}"
        printf -v "formatted_expired_percent_${duration}" "%s" "${formatted_expired_percent[$duration]}"
        printf -v "total_block_vote_${duration}" "%s" "${total_block_vote[$duration]}"
    done

    # Reward Stats Headers
    row_reward_1=(
        "$(format::align "" 'c' '18')"
        "$(format::align "Wins" 'c' '8')"
        "$(format::align "Blocks" 'c' '8')"
        "$(format::align "Votes" 'c' '8')"
        "$(format::align "Slow Blks." 'c' '13')"
        "$(format::align "Exp. Blks." 'c' '13')"
        "$(format::align "Bundles" 'c' '13')")

    row_reward_2=(
        "$(format::align "$period_reward_period_1" 'r' '18')"
        "$(format::align "$formatted_block_vote_total_period_1" 'c' '8')"
        "$(format::align "$formatted_block_period_1" 'c' '8')"
        "$(format::align "$formatted_vote_period_1" 'c' '8')"
        "$(format::align "$formatted_slow_period_1" 'r' '4')"
        "$(format::align "$formatted_slow_percent_period_1" 'l' '6')"
        "$(format::align "$formatted_expired_period_1" 'r' '4')"
        "$(format::align "$formatted_expired_percent_period_1" 'l' '6')"
        "$(format::align "$bundle_period_1" 'c' '13')")

    row_reward_3=(
        "$(format::align "$period_reward_period_2" 'r' '18')"
        "$(format::align "$formatted_block_vote_total_period_2" 'c' '8')"
        "$(format::align "$formatted_block_period_2" 'c' '8')"
        "$(format::align "$formatted_vote_period_2" 'c' '8')"
        "$(format::align "$formatted_slow_period_2" 'r' '4')"
        "$(format::align "$formatted_slow_percent_period_2" 'l' '6')"
        "$(format::align "$formatted_expired_period_2" 'r' '4')"
        "$(format::align "$formatted_expired_percent_period_2" 'l' '6')"
        "$(format::align "$bundle_period_2" 'c' '13')")

    row_reward_4=(
        "$(format::align "$period_reward_period_3" 'r' '18')"
        "$(format::align "$formatted_block_vote_total_period_3" 'c' '8')"
        "$(format::align "$formatted_block_period_3" 'c' '8')"
        "$(format::align "$formatted_vote_period_3" 'c' '8')"
        "$(format::align "$formatted_slow_period_3" 'r' '4')"
        "$(format::align "$formatted_slow_percent_period_3" 'l' '6')"
        "$(format::align "$formatted_expired_period_3" 'r' '4')"
        "$(format::align "$formatted_expired_percent_period_3" 'l' '6')"
        "$(format::align "$bundle_period_3" 'c' '13')")

    row_reward_5=(
        "$(format::align "$period_reward_period_3 ↔ $period_reward_period_4" 'r' '18')"
        "$(format::align "$formatted_block_vote_total_period_4" 'c' '8')"
        "$(format::align "$formatted_block_period_4" 'c' '8')"
        "$(format::align "$formatted_vote_period_4" 'c' '8')"
        "$(format::align "$formatted_slow_period_4" 'r' '4')"
        "$(format::align "$formatted_slow_percent_period_4" 'l' '6')"
        "$(format::align "$formatted_expired_period_4" 'r' '4')"
        "$(format::align "$formatted_expired_percent_period_4" 'l' '6')"
        "$(format::align "$bundle_period_4" 'c' '13')")
}



function monitor::generate:display() {
    trap 'exit_module=true' SIGINT

    # Node Status
    if pgrep -f "subspace-node" >/dev/null; then
        node_status=$(printf "\e[32m●\e[0m")
    else
        node_status=$(printf "\e[31m●\e[0m")
    fi

    # Farmer Status
    if pgrep -f "subspace-farmer" >/dev/null; then
        farmer_status=$(printf "\e[32m●\e[0m")
    else
        farmer_status=$(printf "\e[31m●\e[0m")
    fi

    local exit_prompt=$(printf "E\e[94m\e[4mx\e[0mit")

    printf "\n  %136s\n" "$node_status node   $farmer_status farmer  $exit_prompt"

    local title_reward_left="Reward Stats for $(hostname) (atcmon ver $config_version)"
    local frame_reward_width=101

    # Calculate the width of the lines on both sides of the title
    local header_reward_left=2
    local header_reward_right=$(( (frame_reward_width - ${#title_reward_left}) - $header_reward_left - 2 ))

    # Function to print horizontal line
    print_horizontal_line() {
        printf "%s\n" "$(printf '─%.0s' $(seq 1 $1))"
    }

    printf " ${C_FRAME}╭%s %s %*s╮${C_RESET}\n" "$(print_horizontal_line $header_reward_left)" "$title_reward_left" "" "$(print_horizontal_line $header_reward_right)"
    printf " ${SPACER}%${frame_reward_width}s${SPACER}\n"
    printf " ${SPACER} ${C_BOLD}%-18s   %-8s   %-8s   %-8s   %-13s   %-13s   %-13s ${C_BOLD}${SPACER}\n" "${row_reward_1[@]}"
    printf " ${C_FRAME}┝━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━┯━━━━━━━━━━┯━━━━━━━━━━┯━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━┥${C_RESET}\n"
    printf " ${SPACER} %-18s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-5s %-7s ${SPACER} %-5s %-7s ${SPACER} %-13s ${SPACER} \n" "${row_reward_2[@]}"
    printf " ${SPACER} %-18s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-5s %-7s ${SPACER} %-5s %-7s ${SPACER} %-13s ${SPACER} \n" "${row_reward_3[@]}"
    printf " ${SPACER} %-18s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-5s %-7s ${SPACER} %-5s %-7s ${SPACER} %-13s ${SPACER} \n" "${row_reward_4[@]}"
    printf " ${SPACER} %-18s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-8s ${SPACER} %-5s %-7s ${SPACER} %-5s %-7s ${SPACER} %-13s ${SPACER} \n" "${row_reward_5[@]}"
    printf " ${C_FRAME}╰────────────────────┴──────────┴──────────┴──────────┴───────────────┴───────────────┴───────────────╯${C_RESET}\n"


    printf " ${C_FRAME}  %-42s %58s${C_RESET}\n\n" "" "Updated $updated_time ($process_time)"
}


# Check and install bc and jq
app::dependencies bc
app::dependencies jq

app::set::global:vars
app::init::config

is_first_run=1

count="$config_dashboard_refresh_rate"
trap 'exit_module=true' SIGINT

while true; do

    stty -echo # Disable echoing
    tput civis # Hide cursor

    count=$((count + 1))

    if [[ $count -gt "$config_dashboard_refresh_rate" ]]; then
        # Record start time
        start_time=$(date +%s.%N)

        printf "\033[1A\r\033[K" # Go up one line and clear the line
        printf "\033[1A\r\033[K" # Go up one line and clear the line
        if (( is_first_run == 1 )); then
            message::info " Gathering Metrics and Log Data..."
        else
            # Cover up Auto Refresh message
            message::info "  Gathering Metrics and Log Data..."
        fi

        monitor::pull:reward:metrics

        # Record the time the data was processed
        updated_time=$(date +'%r') 

        # Stop time and calculate the time taken
        process_time=$(format::time "$(bc <<< "$(date +%s.%N) - $start_time")")
        if [[ "$process_time" == "0s" ]]; then
            process_time="<1s"
        fi

        clear
        monitor::generate:display
        count=0
        is_first_run=0
    fi

    read -t 1 -n 1 key

    case "$(echo "$key" | tr '[:upper:]' '[:lower:]')" in
        "r")
            # Refresh the dashboard
            count="$config_dashboard_refresh_rate"
            ;;
        "x" | $'\e')
            exit_module=true
            ;;
    esac

    if (( config_dashboard_refresh_rate - count < 1 )); then
        printf "\n\r\033[K" # Clear one line up
        message::info " Gathering Metrics Data..."
    else
        printf "\r\033[K  Auto refresh in %s...\r" "$(format::time "$((config_dashboard_refresh_rate - count))")"
    fi


    if [[ "$exit_module" == true ]]; then
        exit_module=false
        printf "\r\033[K" # Clear one line up
        tput cnorm # Restore cursor
        stty echo # Enable echoing
        exit
    fi

done
