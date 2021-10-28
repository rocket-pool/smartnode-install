#!/bin/sh

/usr/share/rp-version-check.sh | sponge /var/lib/node_exporter/textfile_collector/rp.prom || true