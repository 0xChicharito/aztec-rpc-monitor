#!/bin/bash

# RPC Health Check - Fully Interactive Installer
# Always prompts for all configuration values

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Config
REPO_URL="https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main"
INSTALL_DIR=$(pwd)

# Display banner
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║${BOLD}      RPC Health Check Monitor - Auto Installer${NC}${CYAN}      ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Installation directory:${NC} $INSTALL_DIR"
echo ""

# Functions
print_step() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

# Step 1: Pre-flight checks
print_step "STEP 1: Pre-flight Checks"

print_status "Checking system requirements..."
REQUIRED_COMMANDS=("curl" "grep" "sed" "crontab")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_COMMANDS+=("$cmd")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -gt 0 ]; then
    print_error "Missing required commands: ${MISSING_COMMANDS[*]}"
    exit 1
fi

print_success "All required commands found"

# Check if Docker Compose exists
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    DOCKER_COMPOSE_EXISTS=true
    print_success "Docker Compose file detected"
else
    DOCKER_COMPOSE_EXISTS=false
    print_warning "No Docker Compose file found"
fi

# Check/create .env
if [ ! -f ".env" ]; then
    print_status "Creating .env file..."
    touch .env
    chmod 600 .env
    print_success ".env file created"
else
    print_success ".env file exists"
fi

# Step 2: Download scripts
print_step "STEP 2: Downloading Monitoring Scripts"

FILES=(
    "rpc_health_check.sh"
    "setup_cron.sh"
)

for file in "${FILES[@]}"; do
    print_status "Downloading $file..."
    if curl -fsSL "$REPO_URL/$file" -o "$file" 2>/dev/null; then
        chmod +x "$file"
        print_success "$file downloaded and made executable"
    else
        print_error "Failed to download $file"
        exit 1
    fi
done

# Step 3: RPC Configuration
print_step "STEP 3: RPC Configuration"

# Check for existing values *first*
CURRENT_ETH_RPC=$(grep "^ETHEREUM_RPC_URL=" .env 2>/dev/null | cut -d '=' -f2)
CURRENT_BEACON=$(grep "^CONSENSUS_BEACON_URL=" .env 2>/dev/null | cut -d '=' -f2)

# Check if BOTH are set
if [ -n "$CURRENT_ETH_RPC" ] && [ -n "$CURRENT_BEACON" ]; then
    echo "Primary RPC endpoints are already configured:"
    print_success "Ethereum RPC: $CURRENT_ETH_RPC"
    print_success "Consensus Beacon: $CURRENT_BEACON"
    echo "Skipping Step 3."
else
    # At least one is missing, so run the full interactive setup
    echo "Please provide your RPC endpoints:"
    echo ""

    # Ethereum RPC Part
    if [ -n "$CURRENT_ETH_RPC" ]; then
        echo -e "${YELLOW}Current Ethereum RPC:${NC} $CURRENT_ETH_RPC"
    fi
    echo "Enter Ethereum RPC URL:"
    read -r ETH_RPC

    if [ -n "$ETH_RPC" ]; then
        sed -i '/^ETHEREUM_RPC_URL=/d' .env 2>/dev/null || true
        echo "ETHEREUM_RPC_URL=$ETH_RPC" >> .env
        print_success "Ethereum RPC saved: $ETH_RPC"
    elif [ -n "$CURRENT_ETH_RPC" ]; then
        print_success "Keeping current Ethereum RPC"
    else
        print_warning "No Ethereum RPC was set."
    fi

    echo ""

    # Beacon Part
    if [ -n "$CURRENT_BEACON" ]; then
        echo -e "${YELLOW}Current Beacon:${NC} $CURRENT_BEACON"
    fi
    echo "Enter Consensus Beacon URL:"
    read -r BEACON_URL

    if [ -n "$BEACON_URL" ]; then
        sed -i '/^CONSENSUS_BEACON_URL=/d' .env 2>/dev/null || true
        echo "CONSENSUS_BEACON_URL=$BEACON_URL" >> .env
        print_success "Beacon saved: $BEACON_URL"
    elif [ -n "$CURRENT_BEACON" ]; then
        print_success "Keeping current Beacon"
    else
        print_warning "No Consensus Beacon was set."
    fi
fi

# Step 4: Backup RPC Configuration
print_step "STEP 4: Backup RPC Configuration"

echo "Configure backup RPC endpoints:"
echo ""

# Backup Ethereum RPCs
CURRENT_BACKUP_ETH=$(grep "^BACKUP_ETHEREUM_RPCS=" .env 2>/dev/null | cut -d '=' -f2)
if [ -n "$CURRENT_BACKUP_ETH" ]; then
    echo -e "${YELLOW}Current backup Ethereum RPCs:${NC}"
    echo "$CURRENT_BACKUP_ETH" | tr ',' '\n' | sed 's/^/  - /'
    echo ""
fi

echo "Enter backup Ethereum RPC URLs (comma-separated):"
echo -e "${BLUE}Example: https://eth.llamarpc.com,https://rpc.ankr.com/eth${NC}"
echo "Press Enter to use defaults"
read -r BACKUP_ETH

if [ -n "$BACKUP_ETH" ]; then
    sed -i '/^BACKUP_ETHEREUM_RPCS=/d' .env 2>/dev/null || true
    echo "BACKUP_ETHEREUM_RPCS=$BACKUP_ETH" >> .env
    print_success "Backup Ethereum RPCs saved"
elif [ -z "$CURRENT_BACKUP_ETH" ]; then
    BACKUP_ETH="https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://eth.drpc.org,https://ethereum.publicnode.com"
    echo "BACKUP_ETHEREUM_RPCS=$BACKUP_ETH" >> .env
    print_success "Using default backup Ethereum RPCs"
else
    print_success "Keeping current backup Ethereum RPCs"
fi

echo ""

# Backup Beacon URLs
CURRENT_BACKUP_BEACON=$(grep "^BACKUP_BEACON_URLS=" .env 2>/dev/null | cut -d '=' -f2)
if [ -n "$CURRENT_BACKUP_BEACON" ]; then
    echo -e "${YELLOW}Current backup Beacon URLs:${NC}"
    echo "$CURRENT_BACKUP_BEACON" | tr ',' '\n' | sed 's/^/  - /'
    echo ""
fi

echo "Enter backup Beacon URLs (comma-separated):"
echo -e "${BLUE}Example: https://ethereum-beacon-api.publicnode.com${NC}"
echo "Press Enter to use defaults"
read -r BACKUP_BEACON

if [ -n "$BACKUP_BEACON" ]; then
    sed -i '/^BACKUP_BEACON_URLS=/d' .env 2>/dev/null || true
    echo "BACKUP_BEACON_URLS=$BACKUP_BEACON" >> .env
    print_success "Backup Beacon URLs saved"
elif [ -z "$CURRENT_BACKUP_BEACON" ]; then
    BACKUP_BEACON="https://ethereum-beacon-api.publicnode.com,https://beaconstate.ethstaker.cc"
    echo "BACKUP_BEACON_URLS=$BACKUP_BEACON" >> .env
    print_success "Using default backup Beacon URLs"
else
    print_success "Keeping current backup Beacon URLs"
fi

# Step 5: Telegram Configuration
print_step "STEP 5: Telegram Notification (Optional)"

CURRENT_BOT_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d '=' -f2)
CURRENT_CHAT_ID=$(grep "^TELEGRAM_CHAT_ID=" .env 2>/dev/null | cut -d '=' -f2)

if [ -n "$CURRENT_BOT_TOKEN" ] && [ -n "$CURRENT_CHAT_ID" ]; then
    echo -e "${YELLOW}Telegram is currently configured${NC}"
    echo ""
fi

echo "Do you want to enable Telegram notifications? (y/n)"
read -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${CYAN}Telegram Setup Instructions:${NC}"
    echo "  1. Open Telegram, search @BotFather"
    echo "  2. Send: /newbot and follow instructions"
    echo "  3. Copy your bot token"
    echo "  4. Search @userinfobot to get your Chat ID"
    echo ""
    
    if [ -n "$CURRENT_BOT_TOKEN" ]; then
        echo -e "${YELLOW}Current Bot Token:${NC} ${CURRENT_BOT_TOKEN:0:20}..."
    fi
    echo "Enter Telegram Bot Token (or press Enter to keep current):"
    read -r BOT_TOKEN
    
    if [ -n "$BOT_TOKEN" ]; then
        sed -i '/^TELEGRAM_BOT_TOKEN=/d' .env 2>/dev/null || true
        echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" >> .env
        print_success "Bot token saved"
    elif [ -n "$CURRENT_BOT_TOKEN" ]; then
        BOT_TOKEN=$CURRENT_BOT_TOKEN
        print_success "Keeping current bot token"
    fi
    
    echo ""
    if [ -n "$CURRENT_CHAT_ID" ]; then
        echo -e "${YELLOW}Current Chat ID:${NC} $CURRENT_CHAT_ID"
    fi
    echo "Enter Telegram Chat ID (or press Enter to keep current):"
    read -r CHAT_ID
    
    if [ -n "$CHAT_ID" ]; then
        sed -i '/^TELEGRAM_CHAT_ID=/d' .env 2>/dev/null || true
        echo "TELEGRAM_CHAT_ID=$CHAT_ID" >> .env
        print_success "Chat ID saved"
    elif [ -n "$CURRENT_CHAT_ID" ]; then
        CHAT_ID=$CURRENT_CHAT_ID
        print_success "Keeping current chat ID"
    fi
    
    # Test Telegram
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        echo ""
        echo "Test Telegram notification now? (y/n)"
        read -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            TEST_MSG="✅ RPC Health Check Monitor installed successfully!"
            RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                -d chat_id="${CHAT_ID}" \
                -d text="${TEST_MSG}")
            
            if echo "$RESPONSE" | grep -q '"ok":true'; then
                print_success "Test message sent successfully!"
            else
                print_error "Failed to send test message"
            fi
        fi
    fi
else
    print_warning "Telegram notifications disabled"
fi

# Step 6: Docker Compose Restart
if [ "$DOCKER_COMPOSE_EXISTS" = true ]; then
    print_step "STEP 6: Docker Compose Restart"
    
    echo "Enable automatic Docker Compose restart on RPC failure?"
    echo "This will restart your containers when switching to backup RPC"
    echo ""
    echo "Enable Docker Compose restart? (y/n)"
    read -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i '/^DOCKER_COMPOSE_RESTART=/d' .env 2>/dev/null || true
        echo "DOCKER_COMPOSE_RESTART=true" >> .env
        print_success "Docker Compose restart enabled"
    else
        sed -i '/^DOCKER_COMPOSE_RESTART=/d' .env 2>/dev/null || true
        echo "DOCKER_COMPOSE_RESTART=false" >> .env
        print_warning "Docker Compose restart disabled"
    fi
fi

# Step 7: Cron Job Setup
print_step "STEP 7: Automatic Monitoring Setup"

echo "Setup automatic RPC monitoring with cron job"
echo ""
echo "Enable automatic monitoring? (y/n)"
read -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Select check frequency:"
    echo "  1) Every 5 minutes  (recommended)"
    echo "  2) Every 10 minutes"
    echo "  3) Every 15 minutes"
    echo "  4) Every 30 minutes"
    echo "  5) Every hour"
    echo ""
    echo "Enter choice (1-5):"
    read -n 1 -r
    echo ""
    
    case $REPLY in
        1) CRON_SCHEDULE="*/5 * * * *" ;;
        2) CRON_SCHEDULE="*/10 * * * *" ;;
        3) CRON_SCHEDULE="*/15 * * * *" ;;
        4) CRON_SCHEDULE="*/30 * * * *" ;;
        5) CRON_SCHEDULE="0 * * * *" ;;
        *) CRON_SCHEDULE="*/5 * * * *" ;;
    esac
    
    CRON_CMD="$CRON_SCHEDULE cd $INSTALL_DIR && ./rpc_health_check.sh >> rpc_health_check.log 2>&1"
    
    # Remove existing cron job
    (crontab -l 2>/dev/null | grep -v "rpc_health_check.sh") | crontab - 2>/dev/null || true
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    
    print_success "Cron job configured: $CRON_SCHEDULE"
else
    print_warning "Automatic monitoring disabled"
    echo "You can set it up later by running: ./setup_cron.sh"
fi

# Final Summary
print_step "Installation Complete! 🎉"

echo -e "${GREEN}${BOLD}✓ RPC Health Check Monitor successfully installed!${NC}"
echo ""

# Display final configuration
ETH_RPC=$(grep "^ETHEREUM_RPC_URL=" .env 2>/dev/null | cut -d '=' -f2)
BEACON=$(grep "^CONSENSUS_BEACON_URL=" .env 2>/dev/null | cut -d '=' -f2)
TELEGRAM_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d '=' -f2)
DOCKER_RESTART=$(grep "^DOCKER_COMPOSE_RESTART=" .env 2>/dev/null | cut -d '=' -f2)

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                 CONFIGURATION SUMMARY                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installation Location:"
echo "  $INSTALL_DIR"
echo ""
echo "RPC Configuration:"
echo "  • Ethereum RPC: ${ETH_RPC:-Not set}"
echo "  • Beacon: ${BEACON:-Not set}"
echo ""
echo "Features:"
if [ -n "$TELEGRAM_TOKEN" ]; then
    echo "  ✓ Telegram notifications: Enabled"
else
    echo "  ✗ Telegram notifications: Disabled"
fi

if [ "$DOCKER_RESTART" = "true" ]; then
    echo "  ✓ Docker Compose restart: Enabled"
else
    echo "  ✗ Docker Compose restart: Disabled"
fi

if crontab -l 2>/dev/null | grep -q "rpc_health_check.sh"; then
    echo "  ✓ Automatic monitoring: Enabled"
else
    echo "  ✗ Automatic monitoring: Disabled"
fi
echo ""

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    QUICK COMMANDS                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Monitor logs in real-time:"
echo "  tail -f rpc_health_check.log"
echo ""
echo "Run manual health check:"
echo "  ./rpc_health_check.sh"
echo ""
echo "Edit configuration:"
echo "  nano .env"
echo ""
echo "View cron jobs:"
echo "  crontab -l"
echo ""
echo "Check if using backup RPC:"
echo "  cat .original_rpc"
echo ""

echo -e "${GREEN}${BOLD}Happy monitoring! 🚀${NC}"
echo ""
