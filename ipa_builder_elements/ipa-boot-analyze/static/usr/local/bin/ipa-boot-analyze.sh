#!/bin/bash

# Wait until all other units have finished starting, systemd-analyze
# refuses to report until the boot is complete.
systemctl is-system-running --wait || true

echo "===== systemd-analyze time ====="
systemd-analyze time
echo "===== systemd-analyze blame ====="
systemd-analyze --no-pager blame
echo "===== systemd-analyze critical-chain ====="
systemd-analyze --no-pager critical-chain

echo "===== critical-chain network-online.target ironic-python-agent.service ====="
systemd-analyze --no-pager critical-chain network-online.target ironic-python-agent.service

echo "===== network and IPA unit timestamps (monotonic, usec since boot) ====="
mapfile -t UNITS < <(systemctl list-units --all --plain --no-legend \
    'network*' 'dhcp-interface@*' 'wicked*' 'NetworkManager*' \
    'systemd-networkd*' 'ironic-python-agent*' | awk '{print $1}')
for unit in "${UNITS[@]}"; do
    echo "--- ${unit}"
    systemctl show -p InactiveExitTimestampMonotonic \
        -p ActiveEnterTimestampMonotonic -p ActiveState "${unit}"
done

echo "===== kernel, DHCP and IPA journal (monotonic) ====="
# journalctl matches on different fields, so join them with "+"
MATCHES=(_TRANSPORT=kernel)
for unit in "${UNITS[@]}"; do
    MATCHES+=(+ "_SYSTEMD_UNIT=${unit}")
done
journalctl -b --no-pager -o short-monotonic "${MATCHES[@]}"
