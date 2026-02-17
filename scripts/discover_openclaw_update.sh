#!/bin/bash
# discover_openclaw_update.sh
# Retrieves critical VPS telemetry for OpenClaw optimization.

echo "Gathering VPS Telemetry..."

# Hostname and IP
echo "HOSTNAME=$(hostname)"
echo "HOST_IP=$(hostname -I | cut -d' ' -f1)"

# CPU Details
echo "CPU_CORES=$(nproc)"
echo "CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)"
echo "CPU_LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)"

# RAM Details (in MB)
echo "RAM_TOTAL_MB=$(free -m | awk '/^Mem:/{print $2}')"
echo "RAM_USED_MB=$(free -m | awk '/^Mem:/{print $3}')"
echo "RAM_FREE_MB=$(free -m | awk '/^Mem:/{print $4}')"

# Disk Details (Root partition)
echo "DISK_TOTAL_GB=$(df -h / | awk 'NR==2 {print $2}')"
echo "DISK_USED_GB=$(df -h / | awk 'NR==2 {print $3}')"
echo "DISK_FREE_GB=$(df -h / | awk 'NR==2 {print $4}')"
echo "DISK_USAGE_PERCENT=$(df -h / | awk 'NR==2 {print $5}')"

# OS Details
echo "OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '\"')"
echo "KERNEL_VERSION=$(uname -r)"

echo "Telemetry gathering complete."
