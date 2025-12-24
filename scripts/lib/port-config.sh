#!/bin/sh
#
# port-config.sh - Port configuration loader
#
# Loads port configuration from .devops/ports.conf or .env files
# Provides port variables with sensible defaults
#
# Usage:
#   source scripts/lib/port-config.sh
#   echo "Frontend runs on port $FRONTEND_PORT"
#
# Ports can be configured in:
#   1. .devops/ports.conf (recommended)
#   2. .env file (environment variables)
#   3. Environment variables (highest priority)
#
# Default ports:
#   FRONTEND_PORT=3000
#   BACKEND_PORT=3030
#   AUTOMATION_PORT=7070
#   METRICS_PORT=9091

# Port configuration file paths
PORT_CONFIG_FILE=".devops/ports.conf"
ENV_FILE=".env"

# Load from .devops/ports.conf if exists
if [ -f "$PORT_CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$PORT_CONFIG_FILE"
fi

# Load from .env if exists (only PORT-related variables)
if [ -f "$ENV_FILE" ]; then
    # Extract PORT-related variables from .env
    # This avoids conflicts with other .env variables
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        case "$key" in
            \#*|'') continue ;;
        esac
        # Only export PORT-related variables
        case "$key" in
            *PORT*|PORT)
                # Remove quotes if present
                value=$(echo "$value" | sed "s/^['\"]//;s/['\"]$//")
                export "$key=$value"
                ;;
        esac
    done < "$ENV_FILE"
fi

# Set defaults if not already set
FRONTEND_PORT=${FRONTEND_PORT:-3000}
BACKEND_PORT=${BACKEND_PORT:-${PORT:-3030}}
AUTOMATION_PORT=${AUTOMATION_PORT:-7070}
METRICS_PORT=${BACKEND_METRICS_PORT:-${METRICS_PORT:-9091}}

# Observability stack ports (optional)
GRAFANA_PORT=${GRAFANA_PORT:-3001}
PROMETHEUS_PORT=${PROMETHEUS_PORT:-9090}
LOKI_PORT=${LOKI_PORT:-3100}
TEMPO_PORT=${TEMPO_PORT:-3200}
OTEL_PORT=${OTEL_PORT:-4318}

# Export all port variables
export FRONTEND_PORT
export BACKEND_PORT
export AUTOMATION_PORT
export METRICS_PORT
export GRAFANA_PORT
export PROMETHEUS_PORT
export LOKI_PORT
export TEMPO_PORT
export OTEL_PORT
