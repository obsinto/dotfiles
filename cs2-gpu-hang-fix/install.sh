#!/usr/bin/env bash
# Instalador da mitigacao do gfx ring timeout do CS2 na RX 7600 (RDNA3).
# Idempotente: pode rodar de novo sem quebrar nada.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
PERF=/sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level

echo ">> Instalando scripts em $BIN"
mkdir -p "$BIN"
install -m 0755 "$HERE/cs2-stable"     "$BIN/cs2-stable"
install -m 0755 "$HERE/zenity-askpass" "$BIN/zenity-askpass"

echo ">> Instalando regra udev (precisa de sudo)"
export SUDO_ASKPASS="$BIN/zenity-askpass"
sudo -A sh -c "
  install -m 0644 '$HERE/99-rx7600-perf-writable.rules' /etc/udev/rules.d/99-rx7600-perf-writable.rules &&
  udevadm control --reload-rules &&
  udevadm trigger --action=add /sys/bus/pci/devices/0000:03:00.0
"

echo ">> Verificando permissao"
ls -l "$PERF"
if [ -w "$PERF" ]; then
  echo ">> OK: $PERF gravavel sem sudo."
else
  echo "!! Ainda nao gravavel. Tente reiniciar ou rode: sudo udevadm trigger --action=add /sys/bus/pci/devices/0000:03:00.0"
fi

cat <<'EOF'

>> FALTA UM PASSO MANUAL (Steam aberto sobrescreve a config, por isso e' manual):
   Steam -> botao direito no CS2 -> Propriedades -> Opcoes de Inicializacao:

   SDL_AUDIODRIVER=pulseaudio RADV_DEBUG=zerovram /home/deyvid/.local/bin/cs2-stable %command% +fps_max 150

EOF
