#!/bin/sh

/usr/share/pacman-metrics.sh | sponge /var/lib/node_exporter/textfile_collector/pacman.prom || true
/usr/share/rp-version-check.sh | sponge /var/lib/node_exporter/textfile_collector/rp.prom || true