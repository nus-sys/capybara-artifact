#!/bin/bash
# Deadman watchdog: if experiments are not cleaned up within TTL, force-clean the
# whole cluster. Arm at bring-up; cleanup_all.sh disarms it on success.
# usage: arm_watchdog.sh [ttl_seconds]   (default 7200 = 2h)
TTL=${1:-7200}
tmux kill-session -t wdog 2>/dev/null
tmux new-session -d -s wdog "sleep $TTL; echo \"[watchdog] TTL expired -> cleanup\" >> ~/capybara-AE-runs/watchdog.log; bash ~/capybara-AE-runs/cleanup_all.sh >> ~/capybara-AE-runs/watchdog.log 2>&1"
echo "watchdog armed: ${TTL}s"
