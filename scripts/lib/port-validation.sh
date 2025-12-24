#!/bin/sh
#
# port-validation.sh - Port validation and conflict detection
#
# Validates port configuration and detects conflicts
#
# Usage:
#   source scripts/lib/port-validation.sh
#   check_port_conflicts

# Check if a port is in use
is_port_in_use() {
    port="$1"
    if command -v lsof >/dev/null 2>&1; then
        # macOS/Linux
        lsof -ti ":$port" >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        # Alternative method
        netstat -an | grep -q ":$port " >/dev/null 2>&1
    else
        # Can't check, assume not in use
        return 1
    fi
}

# Validate port is in valid range (1024-65535)
is_valid_port() {
    port="$1"
    if [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Check for port conflicts in configuration
check_port_conflicts() {
    # Load port configuration
    if [ -f "scripts/lib/port-config.sh" ]; then
        # shellcheck source=/dev/null
        . scripts/lib/port-config.sh
    fi
    
    conflicts=0
    ports_checked=""
    
    # Check each port
    for port_var in FRONTEND_PORT BACKEND_PORT AUTOMATION_PORT METRICS_PORT GRAFANA_PORT PROMETHEUS_PORT LOKI_PORT TEMPO_PORT OTEL_PORT; do
        eval "port=\$$port_var"
        if [ -n "$port" ] && [ "$port" != "" ]; then
            # Check if port is valid
            if ! is_valid_port "$port"; then
                echo "⚠️  $port_var=$port is not in valid range (1024-65535)"
                conflicts=$((conflicts + 1))
                continue
            fi
            
            # Check for duplicates
            if echo "$ports_checked" | grep -q ":$port:"; then
                echo "⚠️  Port conflict: $port_var=$port is already used by another service"
                conflicts=$((conflicts + 1))
            else
                ports_checked="${ports_checked}:$port:"
            fi
            
            # Check if port is in use
            if is_port_in_use "$port"; then
                echo "⚠️  Port $port ($port_var) is already in use"
                conflicts=$((conflicts + 1))
            fi
        fi
    done
    
    if [ "$conflicts" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Validate port configuration file
validate_port_config() {
    config_file="${1:-.devops/ports.conf}"
    
    if [ ! -f "$config_file" ]; then
        return 0  # No config file, use defaults
    fi
    
    # Check for syntax errors (basic check)
    if ! sh -n "$config_file" 2>/dev/null; then
        echo "⚠️  Port config file has syntax errors: $config_file"
        return 1
    fi
    
    return 0
}
