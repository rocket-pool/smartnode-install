#!/bin/sh

UPDATES=$(pacman -Qu | wc -l)
SECURITY=$(arch-audit --upgradable --quiet | wc -l)

# If the currently running kernel is less than the latest available, then a reboot is required.
# not perfect but better than nothing
REBOOT=$([[ $(pacman -Q linux | cut -d " " -f 2) > $(uname -r) ]] && echo 0 || echo 1)

echo "# HELP os_upgrades_pending pacman package pending updates by origin."
echo "# TYPE os_upgrades_pending gauge"
echo "os_upgrades_pending ${UPDATES}"

echo "# HELP os_security_upgrades_pending pacman package pending security updates by origin."
echo "# TYPE os_security_upgrades_pending gauge"
echo "os_security_upgrades_pending ${SECURITY}"

echo "# HELP os_reboot_required Node reboot is required for software updates."
echo "# TYPE os_reboot_required gauge"
echo "os_reboot_required ${REBOOT}"
