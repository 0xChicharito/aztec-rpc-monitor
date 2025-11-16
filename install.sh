#!/bin/bash

# RPC Health Check - Fully Automated Installer
# Auto-configures everything with user input

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
echo -e "${CYAN}║${BOLD}        RPC Health Check Monitor - Auto Installer${NC}${CYAN}        ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Installation directory:${NC} $INSTALL_DIR"
echo ""

# Function to print status
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
        echo ""
        echo "Manual download:"
        echo "  curl -O $REPO_URL/$file"
        echo "  chmod +x $file"
        exit 1
    fi
done

# Step 3: RPC Configuration
print_step "STEP 3: RPC Configuration"

# Check existing values
CURRENT_ETH_RPC=$(grep "^ETHEREUM_RPC_URL=" .env 2>/dev/null | cut -d '=' -f2)
CURRENT_BEACON=$(grep "^CONSENSUS_BEACON_URL=" .env 2>/dev/null | cut -d '=' -f2)

if [ -n "$CURRENT_ETH_RPC" ] && [ -n "$CURRENT_BEACON" ]; then
    echo "Current RPC configuration:"
    echo "  • Ethereum RPC: $CURRENT_ETH_RPC"
    echo "  • Beacon: $CURRENT_BEACON"
    echo ""
    print_success "RPC endpoints already configured"
else
    echo "Please provide your RPC endpoints:"
    echo ""
    
    if [ -z "$CURRENT_ETH_RPC" ]; then
        echo "Enter your Ethereum RPC URL:"
        read -r ETH_RPC
        if [ -n "$ETH_RPC" ]; then
            echo "ETHEREUM_RPC_URL=$ETH_RPC" >> .env
            print_success "Ethereum RPC saved"
        fi
    fi
    
    if [ -z "$CURRENT_BEACON" ]; then
        echo ""
        echo "Enter your Consensus Beacon URL:"
        read -r BEACON_URL
        if [ -n "$BEACON_URL" ]; then
            echo "CONSENSUS_BEACON_URL=$BEACON_URL" >> .env
            print_success "Consensus Beacon saved"
        fi
    fi
fi

# Step 4: Backup RPC Configuration
print_step "STEP 4: Backup RPC Configuration"

CURRENT_BACKUP_ETH=$(grep "^BACKUP_ETHEREUM_RPCS=" .env 2>/dev/null | cut -d '=' -f2)
CURRENT_BACKUP_BEACON=$(grep "^BACKUP_BEACON_URLS=" .env 2>/dev/null | cut -d '=' -f2)

if [ -n "$CURRENT_BACKUP_ETH" ] && [ -n "$CURRENT_BACKUP_BEACON" ]; then
    echo "Current backup configuration:"
    echo "  • Backup Ethereum RPCs: $(echo $CURRENT_BACKUP_ETH | tr ',' ' ')"
    echo "  • Backup Beacon URLs: $(echo $CURRENT_BACKUP_BEACON | tr ',' ' ')"
    echo ""
    print_success "Backup RPCs already configured"
else
    echo "Configure backup RPC endpoints:"
    echo ""
    
    if [ -z "$CURRENT_BACKUP_ETH" ]; then
        echo "Enter backup Ethereum RPC URLs (comma-separated):"
        echo "Example: https://eth.llamarpc.com,https://rpc.ankr.com/eth"
        echo "Or press Enter to use defaults"
        read -r BACKUP_ETH
        if [ -z "$BACKUP_ETH" ]; then
            BACKUP_ETH="https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://eth.drpc.org,https://ethereum.publicnode.com"
        fi
        echo "BACKUP_ETHEREUM_RPCS=$BACKUP_ETH" >> .env
        print_success "Backup Ethereum RPCs saved"
    fi
    
    if [ -z "$CURRENT_BACKUP_BEACON" ]; then
        echo ""
        echo "Enter backup Beacon URLs (comma-separated):"
        echo "Or press Enter to use defaults"
        read -r BACKUP_BEACON
        if [ -z "$BACKUP_BEACON" ]; then
            BACKUP_BEACON="https://ethereum-beacon-api.publicnode.com,https://beaconstate.ethstaker.cc"
        fi
        echo "BACKUP_BEACON_URLS=$BACKUP_BEACON" >> .env
        print_success "Backup Beacon URLs saved"
    fi
fi

# Step 5: Telegram Configuration
print_step "STEP 5: Telegram Notification (Optional)"

CURRENT_BOT_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d '=' -f2)
CURRENT_CHAT_ID=$(grep "^TELEGRAM_CHAT_ID=" .env 2>/dev/null | cut -d '=' -f2)

if [ -n "$CURRENT_BOT_TOKEN" ] && [ -n "$CURRENT_CHAT_ID" ]; then
    echo "Telegram notifications already configured"
    print_success "Telegram is enabled"
else
    echo "Setup Telegram notifications for RPC alerts"
    echo ""
    echo -n "Enable Telegram notifications? (y/n): "
    read -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "To setup Telegram:"
        echo "  1. Open Telegram, search @BotFather"
        echo "  2. Send: /newbot"
        echo "  3. Get your Chat ID from @userinfobot"
        echo ""
        
        echo "Enter Telegram Bot Token:"
        read -r BOT_TOKEN
        
        echo "Enter Telegram Chat ID:"
        read -r CHAT_ID
        
        if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
            echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" >> .env
            echo "TELEGRAM_CHAT_ID=$CHAT_ID" >> .env
            print_success "Telegram configured"
            
            echo ""
            echo -n "Test Telegram now? (y/n): "
            read -n 1 -r
            echo ""
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                TEST_MSG="✅ RPC Monitor installed!"
                RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d text="${TEST_MSG}")
                
                if echo "$RESPONSE" | grep -q '"ok":true'; then
                    print_success "Test message sent!"
                else
                    print_error "Failed to send test message"
                fi
            fi
        fi
    else
        print_warning "Telegram disabled"
    fi
fi

# Step 6: Docker Compose Restart
if [ "$DOCKER_COMPOSE_EXISTS" = true ]; then
    print_step "STEP 6: Docker Compose Restart"
    
    CURRENT_DOCKER_RESTART=$(grep "^DOCKER_COMPOSE_RESTART=" .env 2>/dev/null | cut -d '=' -f2)
    
    if [ -n "$CURRENT_DOCKER_RESTART" ]; then
        echo "Docker Compose restart: $CURRENT_DOCKER_RESTART"
        print_success "Already configured"
    else
        echo "Enable Docker Compose restart on RPC failure?"
        echo ""
        echo -n "Enable? (y/n): "
        read -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "DOCKER_COMPOSE_RESTART=true" >> .env
            print_success "Docker restart enabled"
        else
            echo "DOCKER_COMPOSE_RESTART=false" >> .env
            print_warning "Docker restart disabled"
        fi
    fi
fi

# Step 7: Cron Job Setup
print_step "STEP 7: Automatic Monitoring"

if crontab -l 2>/dev/null | grep -q "rpc_health_check.sh"; then
    echo "Automatic monitoring already configured"
    print_success "Cron job exists"
else
    echo "Setup automatic RPC monitoring"
    echo ""
    echo -n "Enable automatic monitoring? (y/n): "
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
        echo -n "Choice (1-5): "
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
        
        (crontab -l 2>/dev/null | grep -v "rpc_health_check.sh"; echo "$CRON_CMD") | crontab -
        
        print_success "Cron configured: $CRON_SCHEDULE"
    else
        print_warning "Auto-monitoring disabled"
    fi
fi

# Final Summary
print_step "Installation Complete! 🎉"

echo -e "${GREEN}${BOLD}✓ RPC Health Check Monitor installed!${NC}"
echo ""

# Read final config
ETH_RPC=$(grep "^ETHEREUM_RPC_URL=" .env 2>/dev/null | cut -d '=' -f2)
BEACON=$(grep "^CONSENSUS_BEACON_URL=" .env 2>/dev/null | cut -d '=' -f2)
TELEGRAM_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d '=' -f2)
DOCKER_RESTART=$(grep "^DOCKER_COMPOSE_RESTART=" .env 2>/dev/null | cut -d '=' -f2)

echo "Configuration Summary:"
echo "  • Location: $INSTALL_DIR"
echo "  • ETH RPC: ${ETH_RPC:-Not set}"
echo "  • Beacon: ${BEACON:-Not set}"
echo "  • Telegram: $([ -n "$TELEGRAM_TOKEN" ] && echo "Enabled" || echo "Disabled")"
echo "  • Docker restart: $([ "$DOCKER_RESTART" = "true" ] && echo "Enabled" || echo "Disabled")"
echo "  • Auto-monitor: $(crontab -l 2>/dev/null | grep -q "rpc_health_check.sh" && echo "Enabled" || echo "Disabled")"
echo ""

echo "Quick Commands:"
echo "  • View logs:     tail -f rpc_health_check.log"
echo "  • Manual check:  ./rpc_health_check.sh"
echo "  • Edit config:   nano .env"
echo ""

echo -e "${GREEN}${BOLD}Happy monitoring! 🚀${NC}"
echo ""
