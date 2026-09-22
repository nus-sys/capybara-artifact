#!/bin/bash
# Runs ON sw1: /tmp/ae-f12setup.py = era src_rewriting setup (first 389 lines) +
# min-rps seed. The migration target register is p4.Egress.reg_min_rps_server_port
# (era line 383, shipped commented as f1=0 which causes the port-0 wipeout);
# seed it to a live backend port so the first migration wave lands.
S=/home/singtel/inho/Capybara/capybara/p4/switch_fe/capybara_switch_fe_src_rewriting_by_server_setup.py
head -389 "$S" > /tmp/ae-f12setup.py
cat >> /tmp/ae-f12setup.py <<'SEED'

# --- min-rps seed: initialise the migration target to a live backend port
# (10001) so the first migration wave is not steered to port 0. pktgen's 1ms
# timer then keeps reg_min_rps_server_port updated from reg_individual_rps.
p4.Egress.reg_min_rps_server_port.mod(REGISTER_INDEX=0, f1=10001)
bfrt.complete_operations()
print('f12setup: min-rps seed applied (port 10001)')
SEED
echo "built /tmp/ae-f12setup.py lines:"; wc -l /tmp/ae-f12setup.py; echo "--- tail:"; tail -6 /tmp/ae-f12setup.py
