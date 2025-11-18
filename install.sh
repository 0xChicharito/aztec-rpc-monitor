#!/bin/bash

# RPC Health Check - Safe Injection Mode (Retry Logic Added)
# Updates:
# - Added 3 retries loop before switching
# - Added 12s delay between retries
# - Docker command: docker compose up -d

set -e

# --- CONFIGURATION PATHS ---
INSTALL_DIR=$(pwd)
AZTEC_DIR="/root/aztec"
AZTEC_ENV_FILE="$AZTEC_DIR/.env"
CONFIG_FILE="$INSTALL_DIR/rpc_config.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   RPC Health Check - Safe Injection & Recovery Mode      ║${NC}"
echo -e "${CYAN}║          (With 3x Retry & Delay Logic)                   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"

# 1. Check for Aztec .env file
if [ ! -f "$AZTEC_ENV_FILE" ]; then
    echo -e "${RED}Error: File $AZTEC_ENV_FILE not found.${NC}"
    echo "Please ensure you have set up Aztec at $AZTEC_DIR"
    exit 1
fi

# 2. Get Current RPC Config (To be used as Primary)
echo -e "${YELLOW}Reading current configuration from $AZTEC_ENV_FILE...${NC}"
CURRENT_ETH=$(grep "^ETHEREUM_RPC_URL=" "$AZTEC_ENV_FILE" | cut -d '=' -f2)
CURRENT_BEACON=$(grep "^CONSENSUS_BEACON_URL=" "$AZTEC_ENV_FILE" | cut -d '=' -f2)

if [ -z "$CURRENT_ETH" ]; then
    echo "Enter Primary Ethereum RPC URL:"
    read -r CURRENT_ETH
fi
if [ -z "$CURRENT_BEACON" ]; then
    echo "Enter Primary Consensus Beacon URL:"
    read -r CURRENT_BEACON
fi

echo -e "${GREEN}Primary RPCs Configured:${NC}"
echo " - ETH: $CURRENT_ETH"
echo " - Beacon: $CURRENT_BEACON"
echo ""

# 3. Configure Backup RPCs
echo -e "${YELLOW}Configure Backup RPCs (Used only when Primary fails):${NC}"
echo "Enter Backup Ethereum RPC URL:"
read -r BACKUP_ETH
[ -z "$BACKUP_ETH" ] && BACKUP_ETH="https://eth.llamarpc.com"

echo "Enter Backup Consensus Beacon URL:"
read -r BACKUP_BEACON
[ -z "$BACKUP_BEACON" ] && BACKUP_BEACON="https://ethereum-beacon-api.publicnode.com"

# 4. Telegram Config
echo ""
echo "Enter Telegram Bot Token (Press Enter to skip):"
read -r BOT_TOKEN
echo "Enter Telegram Chat ID (Press Enter to skip):"
read -r CHAT_ID

# 5. Generate Separate Config File
cat << EOF > "$CONFIG_FILE"
# Monitoring Configuration
PRIMARY_ETH_RPC="$CURRENT_ETH"
PRIMARY_BEACON_URL="$CURRENT_BEACON"
BACKUP_ETH_RPC="$BACKUP_ETH"
BACKUP_BEACON_URL="$BACKUP_BEACON"

# Telegram
TELEGRAM_BOT_TOKEN="$BOT_TOKEN"
TELEGRAM_CHAT_ID="$CHAT_ID"

# State (Do not edit manually)
IS_USING_BACKUP=false
EOF

echo -e "${GREEN}Monitoring config created at: $CONFIG_FILE${NC}"

# 6. Generate Health Check Script (WITH RETRY LOGIC)
cat << 'EOF' > rpc_health_check.sh
#!/bin/bash

# --- PATHS ---
INSTALL_DIR=$(pwd)
CONFIG_FILE="$INSTALL_DIR/rpc_config.conf"
AZTEC_DIR="/root/aztec"
AZTEC_ENV_FILE="$AZTEC_DIR/.env"

# Load Config
source "$CONFIG_FILE"

# --- SETTINGS ---
MAX_RETRIES=3
RETRY_DELAY=12 # Seconds (between 10-15s)

# --- FUNCTIONS ---

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

send_alert() {
    local msg="$1"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="$msg" \
            -d parse_mode="HTML" > /dev/null
    fi
}

restart_aztec() {
    log_msg "🔄 Applying changes to Aztec Node (docker compose up -d)..."
    if [ -d "$AZTEC_DIR" ]; then
        cd "$AZTEC_DIR" || return
        docker compose up -d
        cd - > /dev/null
    else
        log_msg "❌ Error: Aztec directory not found."
    fi
}

update_aztec_env() {
    local new_eth="$1"
    local new_beacon="$2"
    log_msg "📝 Injecting new RPCs into .env..."
    sed -i "s|^ETHEREUM_RPC_URL=.*|ETHEREUM_RPC_URL=$new_eth|" "$AZTEC_ENV_FILE"
    sed -i "s|^CONSENSUS_BEACON_URL=.*|CONSENSUS_BEACON_URL=$new_beacon|" "$AZTEC_ENV_FILE"
}

update_state() {
    local state="$1" 
    sed -i "s|^IS_USING_BACKUP=.*|IS_USING_BACKUP=$state|" "$CONFIG_FILE"
}

check_url() {
    local url="$1"
    local type="$2" # rpc or beacon
    
    if [ "$type" == "rpc" ]; then
        local response=$(curl -s --max-time 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$url")
        if echo "$response" | grep -q "result"; then return 0; else return 1; fi
    else
        local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url/eth/v1/node/health")
        if [[ "$code" == "200" ]] || [[ "$code" == "206" ]]; then return 0; else return 1; fi
    fi
}

# Check logic wrapper
check_primary_health() {
    # Returns 0 if both healthy, 1 if any fail
    check_url "$PRIMARY_ETH_RPC" "rpc" && check_url "$PRIMARY_BEACON_URL" "beacon"
}

# --- MAIN LOGIC ---

log_msg "🔎 Starting Health Check..."

# Initialize health status
PRIMARY_HEALTHY=false
SUCCESS_COUNT=0

# RETRY LOOP (3 attempts)
for ((i=1; i<=MAX_RETRIES; i++)); do
    if check_primary_health; then
        PRIMARY_HEALTHY=true
        log_msg "✅ Attempt $i/$MAX_RETRIES: Primary RPCs are reachable."
        break
    else
        log_msg "⚠️ Attempt $i/$MAX_RETRIES: Primary RPCs failed."
        
        if [ $i -lt $MAX_RETRIES ]; then
            log_msg "⏳ Waiting ${RETRY_DELAY}s before next check..."
            sleep $RETRY_DELAY
        fi
    fi
done

# DECISION LOGIC BASED ON FINAL STATUS
if [ "$IS_USING_BACKUP" == "false" ]; then
    # Currently on PRIMARY
    if [ "$PRIMARY_HEALTHY" == "false" ]; then
        log_msg "🚨 ALL $MAX_RETRIES ATTEMPTS FAILED. Switching to Backup..."
        
        update_aztec_env "$BACKUP_ETH_RPC" "$BACKUP_BEACON_URL"
        update_state "true"
        send_alert "⚠️ <b>RPC FAILOVER:</b> Primary RPC died after 3 attempts. Switched to Backup RPC."
        restart_aztec
    else
        log_msg "✅ System is healthy on Primary."
    fi

else
    # Currently on BACKUP
    if [ "$PRIMARY_HEALTHY" == "true" ]; then
        log_msg "🎉 PRIMARY RPC STABLE! Switching back..."
        
        update_aztec_env "$PRIMARY_ETH_RPC" "$PRIMARY_BEACON_URL"
        update_state "false"
        send_alert "✅ <b>RPC RECOVERY:</b> Primary RPC recovered. Reverted to Main RPC."
        restart_aztec
    else
        log_msg "⚠️ Primary RPC still unstable. Staying on Backup."
    fi
fi
EOF

chmod +x rpc_health_check.sh

# 7. Setup Cronjob
CRON_CMD="*/5 * * * * cd $INSTALL_DIR && ./rpc_health_check.sh >> rpc_health_check.log 2>&1"
(crontab -l 2>/dev/null | grep -v "rpc_health_check.sh") | crontab - 2>/dev/null || true
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

echo -e "${GREEN}Installation Complete!${NC}"
echo "Retry Logic: 3 attempts, ${RETRY_DELAY}s delay."
echo "Command: docker compose up -d"
