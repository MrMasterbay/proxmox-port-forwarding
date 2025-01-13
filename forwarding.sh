#!/bin/bash

# Made by baGStube Nico
# Version 1.4
# Do not rewrite or steal from this Script!

IPTABLES_SAVE_FILE="/etc/iptables/rules.v4"

show_rules() {
    echo "Current NAT Rules:"
    echo "----------------------------------------"
    iptables -t nat -L PREROUTING -n -v --line-numbers
    echo "----------------------------------------"
}

add_rule() {
    read -p "Enter public IP address (-d): " public_ip
    read -p "Enter destination IP to forward to: " dest_ip
    read -p "Enter protocol (tcp/udp/both): " proto
    read -p "Enter source port (single port or range e.g., 27031-27036): " src_port
    read -p "Enter destination port (single port or range e.g., 27031-27036): " dest_port

    if [[ ! $public_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! $dest_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid IP address format"
        return 1
    fi

    if [[ ! $proto =~ ^(tcp|udp|both)$ ]]; then
        echo "Invalid protocol. Use tcp, udp, or both"
        return 1
    fi

    # Check if ports are ranges
    if [[ $src_port =~ ^([0-9]+)-([0-9]+)$ ]]; then
        src_start="${BASH_REMATCH[1]}"
        src_end="${BASH_REMATCH[2]}"
    else
        if ! [[ "$src_port" =~ ^[0-9]+$ ]]; then
            echo "Invalid source port format"
            return 1
        fi
        src_start=$src_port
        src_end=$src_port
    fi

    if [[ $dest_port =~ ^([0-9]+)-([0-9]+)$ ]]; then
        dest_start="${BASH_REMATCH[1]}"
        dest_end="${BASH_REMATCH[2]}"
    else
        if ! [[ "$dest_port" =~ ^[0-9]+$ ]]; then
            echo "Invalid destination port format"
            return 1
        fi
        dest_start=$dest_port
        dest_end=$dest_port
    fi

    # Validate port ranges
    if [ $((src_end - src_start)) -ne $((dest_end - dest_start)) ]; then
        echo "Source and destination port ranges must have the same size"
        return 1
    fi

    # Add rules for each port in the range
    port_offset=0
    while [ $((src_start + port_offset)) -le $src_end ]; do
        current_src_port=$((src_start + port_offset))
        current_dest_port=$((dest_start + port_offset))

        if [ "$proto" = "both" ]; then
            iptables -t nat -A PREROUTING -p tcp -d $public_ip --dport $current_src_port -j DNAT --to-destination $dest_ip:$current_dest_port
            iptables -t nat -A PREROUTING -p udp -d $public_ip --dport $current_src_port -j DNAT --to-destination $dest_ip:$current_dest_port
        else
            iptables -t nat -A PREROUTING -p $proto -d $public_ip --dport $current_src_port -j DNAT --to-destination $dest_ip:$current_dest_port
        fi
        
        port_offset=$((port_offset + 1))
    done

    echo "Rule(s) added successfully"
    save_rules
}

save_rules() {
    iptables-save > $IPTABLES_SAVE_FILE
    if [ $? -eq 0 ]; then
        echo "Rules saved to $IPTABLES_SAVE_FILE"
    else
        echo "Failed to save rules"
    fi
}

delete_rule() {
    show_rules
    echo "Enter rule numbers to delete (space-separated, e.g., '1 2 3' or 'all' to delete all): "
    read -r rules_to_delete

    if [ "$rules_to_delete" = "all" ]; then
        iptables -t nat -F PREROUTING
        echo "All rules deleted"
    else
        # Convert string to array and sort in descending order
        IFS=' ' read -ra RULES <<< "$rules_to_delete"
        SORTED_RULES=($(printf "%s\n" "${RULES[@]}" | sort -nr))
        
        for rule_num in "${SORTED_RULES[@]}"; do
            if ! [[ "$rule_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid rule number: $rule_num"
                continue
            fi
            iptables -t nat -D PREROUTING $rule_num 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "Rule $rule_num deleted successfully"
            else
                echo "Failed to delete rule $rule_num"
            fi
        done
    fi
    
    save_rules
}

load_rules() {
    if [ -f $IPTABLES_SAVE_FILE ]; then
        iptables-restore < $IPTABLES_SAVE_FILE
        echo "Rules loaded from $IPTABLES_SAVE_FILE"
    else
        echo "No saved rules found."
    fi
}

# Load existing rules on script startup
load_rules

# Set up a cron job to save rules every 5 minutes if not already set
if ! crontab -l | grep -q "iptables-save"; then
    (crontab -l; echo "*/5 * * * * /sbin/iptables-save > $IPTABLES_SAVE_FILE") | crontab -
    echo "Scheduled iptables-save every 5 minutes."
fi

while true; do
    echo ""
    echo "Port Forwarding Management by baGStube Nico"
    echo "1. Show current rules"
    echo "2. Add new forwarding rule"
    echo "3. Delete existing rule"
    echo "4. Exit"
    read -p "Select an option (1-4): " choice

    case $choice in
        1)
            show_rules
            ;;
        2)
            add_rule
            ;;
        3)
            delete_rule
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done
