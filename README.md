# RPC Health Check Monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)](https://www.gnu.org/software/bash/)

Automatically monitor Ethereum RPC and Consensus Beacon health, replace with backup RPC when errors detected, and restore original RPC when recovered. Includes Telegram notifications for all RPC changes.

## ✨ Features

- ✅ Health monitoring for Ethereum RPC endpoint
- ✅ Health monitoring for Consensus Beacon endpoint  
- ✅ Automatic retry on error detection
- ✅ Auto-replace with available backup RPC
- ✅ **Auto-restore original RPC when recovered**
- ✅ **Telegram notifications for RPC changes**
- ✅ **Configurable backup RPCs via .env file**
- ✅ Backup .env file before changes
- ✅ Detailed logging
- ✅ Support for automatic execution via cron job
- ✅ One-command installation

## 🚀 Quick Install

### Method 1: One-Command Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/rpc-health-check/main/install.sh | bash
```

### Method 2: Manual Install

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/rpc-health-check.git
cd rpc-health-check

# Run installer
chmod +x install.sh
./install.sh
```

### Method 3: Manual Setup

```bash
# Download files
wget https://raw.githubusercontent.com/YOUR_USERNAME/rpc-health-check/main/rpc_health_check.sh
wget https://raw.githubusercontent.com/YOUR_USERNAME/rpc-health-check/main/setup_cron.sh
wget https://raw.githubusercontent.com/YOUR_USERNAME/rpc-health-check/main/.env.example

# Setup
chmod +x rpc_health_check.sh setup_cron.sh
cp .env.example .env
nano .env  # Edit configuration

# Install cron job
./setup_cron.sh
```

## 📋 Configuration

### 1. Prepare .env file

The `.env` file contains all configuration. Example:

```bash
# Primary RPC endpoints
ETHEREUM_RPC_URL=https://rpc-eth.node9x.com
CONSENSUS_BEACON_URL=https://beacon-eth.node9x.com

# Validator configuration
VALIDATOR_PRIVATE_KEYS=0x...
COINBASE=0x...
P2P_IP=...

# Backup RPC URLs (comma-separated, required)
BACKUP_ETHEREUM_RPCS=https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://eth.drpc.org

# Backup Beacon URLs (comma-separated, required)
BACKUP_BEACON_URLS=https://ethereum-beacon-api.publicnode.com,https://beaconstate.ethstaker.cc

# Telegram Notification (Optional)
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=123456789
```

### 2. Configure Backup RPCs

**Important:** You must configure backup RPCs in the `.env` file for failover to work.

Add backup Ethereum RPCs (comma-separated):
```bash
BACKUP_ETHEREUM_RPCS=https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://your-backup.com
```

Add backup Beacon URLs (comma-separated):
```bash
BACKUP_BEACON_URLS=https://ethereum-beacon-api.publicnode.com,https://your-backup-beacon.com
```

### 3. Set up Telegram Bot (Optional)

1. **Create a Telegram Bot:**
   - Open Telegram and search for `@BotFather`
   - Send `/newbot` command
   - Follow instructions to create your bot
   - Copy the bot token

2. **Get your Chat ID:**
   - Search for `@userinfobot` on Telegram
   - Start a chat and it will show your Chat ID

3. **Add to .env file:**
   ```bash
   TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
   TELEGRAM_CHAT_ID=123456789
   ```

## 🔧 Usage

### Manual Check

```bash
./rpc_health_check.sh
```

### View Logs

```bash
# Real-time logs
tail -f rpc_health_check.log

# Last 50 lines
tail -n 50 rpc_health_check.log
```

### Cron Job Management

```bash
# View cron jobs
crontab -l

# Edit cron schedule
crontab -e

# Remove cron job
crontab -l | grep -v rpc_health_check.sh | crontab -
```

## 📊 How It Works

### Workflow

```
Start
   ↓
Load backup RPCs from .env
   ↓
Original RPC saved? 
   ↓ Yes
Check original RPC
   ↓ Working?
   ↓ Yes → Restore original RPC → Send Telegram → Delete .original_rpc
   ↓ No
Check current RPC
   ↓ Failed?
   ↓ Yes → Save original RPC → Find backup from .env → Send Telegram
   ↓
End
```

### Key Features

1. **Load Backup RPCs from .env**: Script reads your custom backup RPCs from `.env` file
2. **Check Original RPC First**: If using backup, checks if original has recovered
3. **Auto-Restore**: Switches back to original RPC when it recovers
4. **Telegram Alerts**: Notifies on all RPC changes
5. **Retry Logic**: Retries 3 times before declaring failure

## 📱 Telegram Notifications

### Notification Types

#### 1. RPC Failure & Replacement
```
🚨 RPC Failure Alert

❌ Ethereum RPC failed after 3 attempts:
https://rpc-eth.node9x.com

✅ Switched to backup RPC:
https://eth.llamarpc.com

Time: 2024-11-16 10:30:45
```

#### 2. RPC Restoration
```
🎉 RPC Restored

✅ Original Ethereum RPC has recovered and been restored:
https://rpc-eth.node9x.com

Time: 2024-11-16 11:45:20
```

#### 3. Critical Alert
```
🚨 CRITICAL: RPC Failure

❌ Ethereum RPC failed:
https://rpc-eth.node9x.com

⚠️ No backup RPC available!

Time: 2024-11-16 12:00:00
```

## 🔍 Monitoring

### Check Current Status

```bash
# View current RPC configuration
grep -E "(ETHEREUM_RPC|CONSENSUS_BEACON)" .env

# Check if using backup RPC
cat .original_rpc 2>/dev/null && echo "Using backup RPC" || echo "Using original RPC"

# View recent activity
tail -n 20 rpc_health_check.log
```

### Dashboard (Optional)

You can create a simple dashboard:

```bash
# Create monitoring script
cat > monitor.sh << 'SCRIPT'
#!/bin/bash
clear
echo "=== RPC Health Monitor ==="
echo ""
echo "Current RPC:"
grep "^ETHEREUM_RPC_URL=" .env | cut -d '=' -f2
echo ""
echo "Current Beacon:"
grep "^CONSENSUS_BEACON_URL=" .env | cut -d '=' -f2
echo ""
if [ -f .original_rpc ]; then
    echo "Status: Using Backup RPC"
    echo "Original RPC:"
    cat .original_rpc
else
    echo "Status: Using Original RPC"
fi
echo ""
echo "Recent logs:"
tail -n 10 rpc_health_check.log
SCRIPT

chmod +x monitor.sh
./monitor.sh
```

## 🛠️ Troubleshooting

### Script not running

```bash
# Check permissions
ls -la rpc_health_check.sh

# Grant permissions
chmod +x rpc_health_check.sh
```

### Cron job not executing

```bash
# Check cron service
sudo systemctl status cron

# Start cron if needed
sudo systemctl start cron

# Check cron logs
grep CRON /var/log/syslog
```

### Telegram not working

```bash
# Test Telegram API
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage" \
  -d chat_id=<YOUR_CHAT_ID> \
  -d text="Test message"

# Verify .env configuration
grep TELEGRAM .env
```

### No backup RPCs available

```bash
# Add more backup RPCs to .env
nano .env

# Edit BACKUP_ETHEREUM_RPCS and BACKUP_BEACON_URLS
# Example:
# BACKUP_ETHEREUM_RPCS=https://eth1.com,https://eth2.com,https://eth3.com
```

## 📁 File Structure

```
rpc-health-check/
├── install.sh              # Auto installer script
├── rpc_health_check.sh     # Main monitoring script
├── setup_cron.sh           # Cron job setup script
├── .env.example            # Example configuration file
├── .env                    # Your configuration (create from .example)
├── .original_rpc           # Auto-generated backup RPC file
├── rpc_health_check.log    # Auto-generated log file
├── .gitignore              # Git ignore file
├── README.md               # This file
├── QUICKSTART.md           # Quick start guide
└── CHANGELOG.md            # Version history
```

## 🔒 Security

- ⚠️ `.env` file contains private keys - **NEVER** commit to git
- ⚠️ `.gitignore` is configured to exclude sensitive files
- ⚠️ Set file permissions: `chmod 600 .env`
- ⚠️ Keep Telegram bot token secure
- ⚠️ Use HTTPS for all RPC endpoints
- ⚠️ Regularly rotate API keys and tokens

## 📝 Advanced Configuration

### Custom Check Interval

Edit `setup_cron.sh`:

```bash
# Every 5 minutes (default)
CRON_SCHEDULE="*/5 * * * *"

# Every minute (intensive monitoring)
CRON_SCHEDULE="* * * * *"

# Every hour
CRON_SCHEDULE="0 * * * *"
```

### Custom Timeout and Retries

Edit `rpc_health_check.sh`:

```bash
TIMEOUT=10        # Request timeout (seconds)
MAX_RETRIES=3     # Retries before failover
```

### Add More Backup RPCs

Edit `.env`:

```bash
# Add as many backups as needed (comma-separated)
BACKUP_ETHEREUM_RPCS=https://rpc1.com,https://rpc2.com,https://rpc3.com,https://rpc4.com

BACKUP_BEACON_URLS=https://beacon1.com,https://beacon2.com,https://beacon3.com
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Ethereum community for RPC endpoints
- Telegram for notification API
- All contributors and users

## 📞 Support

- Create an issue for bug reports
- Discussions for questions and ideas
- Pull requests for contributions

---

**Made with ❤️ for the Ethereum community**
