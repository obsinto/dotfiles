#!/usr/bin/env bash
# Reverte a mitigacao.
set -euo pipefail
BIN="$HOME/.local/bin"
export SUDO_ASKPASS="$BIN/zenity-askpass"

echo ">> Removendo regra udev e voltando GPU pra 'auto' (sudo)"
sudo -A sh -c '
  rm -f /etc/udev/rules.d/99-rx7600-perf-writable.rules
  udevadm control --reload-rules
  PERF=/sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level
  chgrp root "$PERF" 2>/dev/null || true
  chmod 0644 "$PERF" 2>/dev/null || true
  echo auto > "$PERF" 2>/dev/null || true
'

echo ">> Removendo wrapper (zenity-askpass fica, e util pra outros sudos)"
rm -f "$BIN/cs2-stable"

echo ">> Pronto. Lembre de tirar /home/deyvid/.local/bin/cs2-stable das Opcoes de Inicializacao do CS2 no Steam."
