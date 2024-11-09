#!/bin/bash

# Made by baGStube Nico
# Version 1.0
# Do not rewrite or steal from this Script!

show_rules() {
    echo "Current NAT Rules:"
    echo "----------------------------------------"
    iptables -t nat -L PREROUTING -n -v
    echo "----------------------------------------"
}

add_rule() {
    read -p "Enter public IP address (-d): " public_ip
    read -p "Enter destination IP to forward to: " dest_ip
    read -p "Enter protocol (tcp/udp): " proto
    read -p "Enter source port: " src_port
    read -p "Enter destination port: " dest_port

    if [[ ! $public_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! $dest_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid IP address format"
        return 1
    fi

    if [[ ! $proto =~ ^(tcp|udp)$ ]]; then
        echo "Invalid protocol. Use tcp or udp"
        return 1
    fi

    if ! [[ "$src_port" =~ ^[0-9]+$ ]] || ! [[ "$dest_port" =~ ^[0-9]+$ ]]; then
        echo "Invalid port number"
        return 1
    fi

    iptables -t nat -A PREROUTING -p $proto -d $public_ip --dport $src_port -j DNAT --to-destination $dest_ip:$dest_port
    echo "Rule added successfully"
}

delete_rule() {
    show_rules
    read -p "Enter rule number to delete (1, 2, etc.): " rule_num

    if ! [[ "$rule_num" =~ ^[0-9]+$ ]]; then
        echo "Invalid rule number"
        return 1
    fi

    iptables -t nat -D PREROUTING $rule_num
    echo "Rule deleted successfully"
}

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
