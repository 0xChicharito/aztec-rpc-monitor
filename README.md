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

# Quick Installation Guide for Existing Directory

## For users with existing .env file (like /root/aztec)

```bash
curl -O https://raw.githubusercontent.com/0xChicharito/aztec-rpc-monitor/main/install.sh && chmod +x install.sh && ./install.sh
```
That's it! 🚀

---

**Made with ❤️ for the Ethereum community**
