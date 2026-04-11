#!/usr/bin/env bash
set -euo pipefail

# ─── Cores ───────────────────────────────────────────────────────────────────
RESET='\033[0m'; BOLD='\033[1m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
GREEN='\033[0;32m'; CYAN='\033[0;36m'; DIM='\033[2m'; WHITE='\033[1;37m'
BG_RED='\033[41m'

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/sensors-monitor"
CONFIG_FILE="$CONFIG_DIR/config.env"
MONITOR_SCRIPT="$INSTALL_DIR/sensors-monitor"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$USER_SYSTEMD_DIR/sensors-monitor.service"

info()    { echo -e "  ${CYAN}${BOLD}→${RESET} $1"; }
success() { echo -e "  ${GREEN}${BOLD}✓${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}${BOLD}!${RESET} $1"; }
error()   { echo -e "  ${RED}${BOLD}✗${RESET} $1"; }
ask()     { echo -ne "  ${WHITE}${BOLD}?${RESET} $1 "; }

header() {
    clear || true
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║        Instalação — Monitor de Temperatura           ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

section() {
    echo ""
    echo -e "  ${BOLD}${CYAN}── $1${RESET}"
    echo ""
}

# ─── Verifica dependências ───────────────────────────────────────────────────
check_deps() {
    section "Verificando dependências"
    local missing=()
    for cmd in bash sensors python3 curl awk systemctl; do
        if command -v "$cmd" &>/dev/null; then
            success "$cmd encontrado"
        else
            error "$cmd não encontrado"
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        warn "Dependências faltando: ${missing[*]}"
        ask "Instalar automaticamente as suportadas por apt? (s/N)"; read -r resp
        if [[ "$resp" =~ ^[Ss]$ ]]; then
            sudo apt-get update -qq
            for pkg in "${missing[@]}"; do
                case "$pkg" in
                    sensors) pkg="lm-sensors" ;;
                    bash|python3|curl|awk) ;;
                    systemctl) continue ;;
                    *) continue ;;
                esac
                sudo apt-get install -y "$pkg"
            done
            success "Dependências instaladas."
        else
            error "Instale as dependências e execute novamente."
            exit 1
        fi
    fi
}

# ─── Configuração interativa ─────────────────────────────────────────────────
configure() {
    section "Configuração"

    ask "URL do Webhook do Discord (Enter para pular):"; read -r DISCORD_WEBHOOK
    echo ""
    if [[ -n "$DISCORD_WEBHOOK" ]]; then
        if [[ "$DISCORD_WEBHOOK" =~ ^https://discord(app)?\.com/api/webhooks/ ]]; then
            success "Webhook válido."
        else
            warn "URL parece inválida, continuando assim mesmo."
        fi
    else
        warn "Notificações do Discord desativadas."
    fi

    echo ""
    info "Limiares recomendados para Ryzen 5 9600X + RX 7600 + DDR5."
    info "A RX 7600 foi ajustada para não tratar pico curto de hotspot como crítico."
    ask "Usar limiares recomendados? (S/n)"; read -r use_defaults

    if [[ "$use_defaults" =~ ^[Nn]$ ]]; then
        ask "CPU ATENÇÃO °C         (padrão: 85):"; read -r CPU_WARN;      CPU_WARN=${CPU_WARN:-85}
        ask "CPU CRÍTICO °C         (padrão: 92):"; read -r CPU_CRIT;      CPU_CRIT=${CPU_CRIT:-92}
        ask "GPU Edge ATENÇÃO °C    (padrão: 80):"; read -r GPU_EDGE_WARN; GPU_EDGE_WARN=${GPU_EDGE_WARN:-80}
        ask "GPU Edge CRÍTICO °C    (padrão: 90):"; read -r GPU_EDGE_CRIT; GPU_EDGE_CRIT=${GPU_EDGE_CRIT:-90}
        ask "GPU Hotspot ATENÇÃO °C (padrão: 95):"; read -r GPU_JCT_WARN;  GPU_JCT_WARN=${GPU_JCT_WARN:-95}
        ask "GPU Hotspot CRÍTICO °C (padrão: 105):"; read -r GPU_JCT_CRIT; GPU_JCT_CRIT=${GPU_JCT_CRIT:-105}
        ask "RAM ATENÇÃO °C         (padrão: 55):"; read -r RAM_WARN;      RAM_WARN=${RAM_WARN:-55}
        ask "RAM CRÍTICO °C         (padrão: 80):"; read -r RAM_CRIT;      RAM_CRIT=${RAM_CRIT:-80}
        ask "SSD ATENÇÃO °C         (padrão: 60):"; read -r SSD_WARN;      SSD_WARN=${SSD_WARN:-60}
        ask "SSD CRÍTICO °C         (padrão: 75):"; read -r SSD_CRIT;      SSD_CRIT=${SSD_CRIT:-75}
    else
        CPU_WARN=85;      CPU_CRIT=92
        GPU_EDGE_WARN=80; GPU_EDGE_CRIT=90
        GPU_JCT_WARN=95;  GPU_JCT_CRIT=105
        RAM_WARN=55;      RAM_CRIT=80
        SSD_WARN=60;      SSD_CRIT=75
        success "Limiares recomendados aplicados."
    fi

    echo ""
    ask "Intervalo de atualização em segundos (padrão: 2):"; read -r INTERVAL; INTERVAL=${INTERVAL:-2}
    ask "Cooldown entre alertas Discord em segundos (padrão: 300):"; read -r NOTIFY_COOLDOWN; NOTIFY_COOLDOWN=${NOTIFY_COOLDOWN:-300}
    ask "Nome desta máquina no Discord (padrão: $(hostname)):"; read -r MACHINE_NAME; MACHINE_NAME=${MACHINE_NAME:-$(hostname)}

    echo ""
    info "Persistência de alertas para evitar spam por pico curto."
    ask "Hotspot WARN: nº de leituras seguidas (padrão: 3):"; read -r GPU_JCT_WARN_STREAK_REQUIRED; GPU_JCT_WARN_STREAK_REQUIRED=${GPU_JCT_WARN_STREAK_REQUIRED:-3}
    ask "Hotspot CRIT: nº de leituras seguidas (padrão: 5):"; read -r GPU_JCT_CRIT_STREAK_REQUIRED; GPU_JCT_CRIT_STREAK_REQUIRED=${GPU_JCT_CRIT_STREAK_REQUIRED:-5}
    ask "Histerese em °C para limpar estado (padrão: 3):"; read -r ALERT_HYSTERESIS; ALERT_HYSTERESIS=${ALERT_HYSTERESIS:-3}

    echo ""
    success "Configuração concluída."
}

# ─── Salva config ─────────────────────────────────────────────────────────────
save_config() {
    section "Salvando configuração"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
# sensors-monitor — gerado em $(date)
# ⚠️  Este arquivo contém o webhook do Discord. Não faça backup em nuvem sem criptografia.
DISCORD_WEBHOOK="${DISCORD_WEBHOOK}"

# CPU — AMD Ryzen 5 9600X (throttling em 95°C)
CPU_WARN=${CPU_WARN}
CPU_CRIT=${CPU_CRIT}

# GPU Edge — AMD RX 7600
GPU_EDGE_WARN=${GPU_EDGE_WARN}
GPU_EDGE_CRIT=${GPU_EDGE_CRIT}

# GPU Junction/Hotspot — AMD RX 7600
# Ajustado para evitar spam com picos curtos
GPU_JCT_WARN=${GPU_JCT_WARN}
GPU_JCT_CRIT=${GPU_JCT_CRIT}
GPU_JCT_MAX=110

# GPU Memory — AMD RX 7600 (GDDR6)
MEM_WARN=85
MEM_CRIT=100

# RAM DDR5
RAM_WARN=${RAM_WARN}
RAM_CRIT=${RAM_CRIT}

# SSD NVMe
SSD_WARN=${SSD_WARN}
SSD_CRIT=${SSD_CRIT}

INTERVAL=${INTERVAL}
NOTIFY_COOLDOWN=${NOTIFY_COOLDOWN}
MACHINE_NAME="${MACHINE_NAME}"

# Anti-spam / persistência
ALERT_HYSTERESIS=${ALERT_HYSTERESIS}
CPU_WARN_STREAK_REQUIRED=2
CPU_CRIT_STREAK_REQUIRED=3
GPU_EDGE_WARN_STREAK_REQUIRED=2
GPU_EDGE_CRIT_STREAK_REQUIRED=3
GPU_JCT_WARN_STREAK_REQUIRED=${GPU_JCT_WARN_STREAK_REQUIRED}
GPU_JCT_CRIT_STREAK_REQUIRED=${GPU_JCT_CRIT_STREAK_REQUIRED}
GPU_MEM_WARN_STREAK_REQUIRED=2
GPU_MEM_CRIT_STREAK_REQUIRED=3
RAM_WARN_STREAK_REQUIRED=2
RAM_CRIT_STREAK_REQUIRED=3
SSD_WARN_STREAK_REQUIRED=2
SSD_CRIT_STREAK_REQUIRED=3
EOF
    chmod 600 "$CONFIG_FILE"
    success "Salvo em ${CONFIG_FILE}"
    warn "⚠️  Não inclua este arquivo em backups não criptografados."
}

# ─── Instala script principal ─────────────────────────────────────────────────
install_monitor() {
    section "Instalando sensors-monitor"
    mkdir -p "$INSTALL_DIR"

    cat > "$MONITOR_SCRIPT" <<'MONITOR_EOF'
#!/usr/bin/env bash
set -u

CONFIG="$HOME/.config/sensors-monitor/config.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

INTERVAL=${INTERVAL:-2}

CPU_WARN=${CPU_WARN:-85}
CPU_CRIT=${CPU_CRIT:-92}

GPU_EDGE_WARN=${GPU_EDGE_WARN:-80}
GPU_EDGE_CRIT=${GPU_EDGE_CRIT:-90}

GPU_JCT_WARN=${GPU_JCT_WARN:-95}
GPU_JCT_CRIT=${GPU_JCT_CRIT:-105}
GPU_JCT_MAX=${GPU_JCT_MAX:-110}

MEM_WARN=${MEM_WARN:-85}
MEM_CRIT=${MEM_CRIT:-100}

RAM_WARN=${RAM_WARN:-55}
RAM_CRIT=${RAM_CRIT:-80}

SSD_WARN=${SSD_WARN:-60}
SSD_CRIT=${SSD_CRIT:-75}

NOTIFY_COOLDOWN=${NOTIFY_COOLDOWN:-300}
MACHINE_NAME=${MACHINE_NAME:-$(hostname)}

ALERT_HYSTERESIS=${ALERT_HYSTERESIS:-3}

CPU_WARN_STREAK_REQUIRED=${CPU_WARN_STREAK_REQUIRED:-2}
CPU_CRIT_STREAK_REQUIRED=${CPU_CRIT_STREAK_REQUIRED:-3}
GPU_EDGE_WARN_STREAK_REQUIRED=${GPU_EDGE_WARN_STREAK_REQUIRED:-2}
GPU_EDGE_CRIT_STREAK_REQUIRED=${GPU_EDGE_CRIT_STREAK_REQUIRED:-3}
GPU_JCT_WARN_STREAK_REQUIRED=${GPU_JCT_WARN_STREAK_REQUIRED:-3}
GPU_JCT_CRIT_STREAK_REQUIRED=${GPU_JCT_CRIT_STREAK_REQUIRED:-5}
GPU_MEM_WARN_STREAK_REQUIRED=${GPU_MEM_WARN_STREAK_REQUIRED:-2}
GPU_MEM_CRIT_STREAK_REQUIRED=${GPU_MEM_CRIT_STREAK_REQUIRED:-3}
RAM_WARN_STREAK_REQUIRED=${RAM_WARN_STREAK_REQUIRED:-2}
RAM_CRIT_STREAK_REQUIRED=${RAM_CRIT_STREAK_REQUIRED:-3}
SSD_WARN_STREAK_REQUIRED=${SSD_WARN_STREAK_REQUIRED:-2}
SSD_CRIT_STREAK_REQUIRED=${SSD_CRIT_STREAK_REQUIRED:-3}

COOLDOWN_DIR="/tmp/sensors-monitor-cooldown"
STATE_DIR="/tmp/sensors-monitor-state"
mkdir -p "$COOLDOWN_DIR" "$STATE_DIR"
chmod 700 "$COOLDOWN_DIR" "$STATE_DIR"

RESET=$'\033[0m'; BOLD=$'\033[1m'; YELLOW=$'\033[0;33m'
GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; WHITE=$'\033[1;37m'
DIM=$'\033[2m'; BG_RED=$'\033[41m'

DAEMON_MODE=0
[[ "${1:-}" == "--daemon" ]] && DAEMON_MODE=1

cleanup() {
    tput cnorm 2>/dev/null || true
    echo -e "${RESET}"
}
trap cleanup EXIT INT TERM

log_msg() {
    local level=$1
    shift
    if [[ "$DAEMON_MODE" -eq 1 ]]; then
        printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
    fi
}

temp_color() {
    local v=$1 w=$2 c=$3
    if awk "BEGIN{exit !($v >= $c)}"; then
        echo -e "${BG_RED}${WHITE}"
    elif awk "BEGIN{exit !($v >= $w)}"; then
        echo -e "${YELLOW}"
    else
        echo -e "${GREEN}"
    fi
}

draw_bar() {
    local v=$1 max=$2 w=$3 c=$4
    local width=30
    local filled
    filled=$(awk "BEGIN{f=int($v*$width/$max); if(f<0)f=0; if(f>$width)f=$width; print f}")

    local color
    color=$(temp_color "$v" "$w" "$c")

    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<width; i++)); do bar+="░"; done
    echo -e "${color}${bar}${RESET}"
}

sensor_line() {
    local label=$1 v=$2 w=$3 c=$4 max=${5:-110}
    local color
    color=$(temp_color "$v" "$w" "$c")
    local bar
    bar=$(draw_bar "$v" "$max" "$w" "$c")
    local icon="[ OK ]"
    if awk "BEGIN{exit !($v >= $c)}"; then
        icon="[CRIT]"
    elif awk "BEGIN{exit !($v >= $w)}"; then
        icon="[WARN]"
    fi
    printf "  ${DIM}%-26s${RESET} %s %s ${color}%s°C${RESET}\n" \
        "$label" "$bar" "${color}${icon}${RESET}" "$v"
}

build_discord_context() {
    local sensor=$1 level=$2 fan=$3 val=${4:-0}
    local context="" fan_info=""

    [[ -n "$fan" && "$fan" != "N/A" && "$fan" != "0" ]] && fan_info="**Fan GPU:** \`${fan} RPM\`"
    [[ "$fan" == "0" ]] && fan_info="**Fan GPU:** \`0 RPM — cooler parado ou passivo ⚠️\`"

    case "$sensor" in
        "CPU")
            [[ "$level" == "CRIT" ]] \
                && context="CPU próxima do throttling. Se sustentar, revise fan curve e fluxo de ar." \
                || context="CPU em carga alta. Observe se permanece elevada por vários minutos."
            ;;
        "GPU Edge")
            [[ "$level" == "CRIT" ]] \
                && context="Temperatura global da GPU alta. Verifique airflow do gabinete." \
                || context="GPU Edge acima do ideal. Observe o comportamento durante o jogo."
            ;;
        "GPU Junction")
            local margem
            margem=$(awk "BEGIN{printf \"%d\", $GPU_JCT_MAX - $val}")
            [[ "$level" == "CRIT" ]] \
                && context="Hotspot sustentado e a ${margem}°C do limite real (${GPU_JCT_MAX}°C). Vale revisar airflow, curva de fan ou undervolt." \
                || context="Hotspot elevado, mas ainda abaixo do limite real. Picos curtos não devem gerar alarme imediato."
            ;;
        "GPU Memory")
            context="Memória GDDR6 elevada. Verifique ventilação da placa e do gabinete."
            ;;
        "RAM DDR5")
            [[ "$level" == "CRIT" ]] \
                && context="RAM DDR5 em temperatura crítica. Verifique airflow e perfil EXPO/XMP." \
                || context="RAM DDR5 aquecendo. Observe se é temperatura sustentada."
            ;;
        "SSD NVMe")
            [[ "$level" == "CRIT" ]] \
                && context="SSD próximo de throttling térmico." \
                || context="SSD aquecendo. Observe a ventilação na região do NVMe."
            ;;
        "GPU Fan")
            context="Fan da GPU reportando 0 RPM com temperatura elevada."
            ;;
    esac

    echo "${context}|${fan_info}"
}

_cooldown_key() {
    local sensor=$1 level=${2:-"ANY"}
    echo "${sensor}_${level}" | tr ' ' '_' | tr -cd '[:alnum:]_'
}

_get_last_notified() {
    local key
    key=$(_cooldown_key "$1" "${2:-}")
    local file="$COOLDOWN_DIR/${key}"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo 0
    fi
}

_set_last_notified() {
    local key
    key=$(_cooldown_key "$1" "${2:-}")
    echo "$3" > "$COOLDOWN_DIR/${key}"
}

_state_file() {
    local sensor=$1
    echo "$STATE_DIR/$(echo "$sensor" | tr ' ' '_' | tr -cd '[:alnum:]_').state"
}

_get_state_value() {
    local sensor=$1 field=$2
    local file
    file=$(_state_file "$sensor")
    [[ -f "$file" ]] || { echo ""; return; }
    awk -F= -v k="$field" '$1==k {print $2}' "$file"
}

_set_state() {
    local sensor=$1 status=$2 warn_count=$3 crit_count=$4
    local file
    file=$(_state_file "$sensor")
    cat > "$file" <<EOF
status=$status
warn_count=$warn_count
crit_count=$crit_count
EOF
}

discord_notify() {
    local sensor=$1 val=$2 level=$3 fan=${4:-"N/A"}
    [[ -z "${DISCORD_WEBHOOK:-}" ]] && return

    local now
    now=$(date +%s)

    local last
    last=$(_get_last_notified "$sensor" "$level")

    if (( now - last < NOTIFY_COOLDOWN )); then
        local remaining=$(( NOTIFY_COOLDOWN - (now - last) ))
        log_msg "DEBUG" "Cooldown ativo para ${sensor}/${level}: faltam ${remaining}s"
        return
    fi

    _set_last_notified "$sensor" "$level" "$now"

    local color=16776960 emoji="🟡" title="Temperatura elevada"
    [[ "$level" == "CRIT" ]] && color=15158332 && emoji="🔴" && title="TEMPERATURA CRÍTICA"

    local raw
    raw=$(build_discord_context "$sensor" "$level" "$fan" "$val")
    local context="${raw%%|*}"
    local fan_info="${raw##*|}"

    local fields="[
        {\"name\":\"Máquina\",\"value\":\"\`${MACHINE_NAME}\`\",\"inline\":true},
        {\"name\":\"Sensor\",\"value\":\"\`${sensor}\`\",\"inline\":true},
        {\"name\":\"Leitura\",\"value\":\"\`${val}°C\`\",\"inline\":true}"
    [[ -n "$fan_info" ]] && fields+=",{\"name\":\"Cooler\",\"value\":\"${fan_info}\",\"inline\":false}"
    [[ -n "$context"  ]] && fields+=",{\"name\":\"Diagnóstico\",\"value\":\"${context}\",\"inline\":false}"
    fields+="]"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK" \
        -H "Content-Type: application/json" \
        --max-time 10 \
        -d "{\"embeds\":[{
            \"title\":\"${emoji} ${title}\",
            \"color\":${color},
            \"fields\":${fields},
            \"footer\":{\"text\":\"sensors-monitor • ${MACHINE_NAME}\"},
            \"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        }]}")

    if [[ "$http_code" =~ ^2 ]]; then
        log_msg "INFO" "Alerta enviado: ${sensor} ${val}°C (${level})"
    else
        log_msg "ERROR" "Falha ao enviar alerta Discord para ${sensor} — HTTP ${http_code}"
        _set_last_notified "$sensor" "$level" "$last"
    fi
}

required_streak() {
    local sensor=$1 level=$2
    case "$sensor:$level" in
        "CPU:WARN") echo "$CPU_WARN_STREAK_REQUIRED" ;;
        "CPU:CRIT") echo "$CPU_CRIT_STREAK_REQUIRED" ;;
        "GPU Edge:WARN") echo "$GPU_EDGE_WARN_STREAK_REQUIRED" ;;
        "GPU Edge:CRIT") echo "$GPU_EDGE_CRIT_STREAK_REQUIRED" ;;
        "GPU Junction:WARN") echo "$GPU_JCT_WARN_STREAK_REQUIRED" ;;
        "GPU Junction:CRIT") echo "$GPU_JCT_CRIT_STREAK_REQUIRED" ;;
        "GPU Memory:WARN") echo "$GPU_MEM_WARN_STREAK_REQUIRED" ;;
        "GPU Memory:CRIT") echo "$GPU_MEM_CRIT_STREAK_REQUIRED" ;;
        "RAM DDR5:WARN") echo "$RAM_WARN_STREAK_REQUIRED" ;;
        "RAM DDR5:CRIT") echo "$RAM_CRIT_STREAK_REQUIRED" ;;
        "SSD NVMe:WARN") echo "$SSD_WARN_STREAK_REQUIRED" ;;
        "SSD NVMe:CRIT") echo "$SSD_CRIT_STREAK_REQUIRED" ;;
        *) echo 1 ;;
    esac
}

check_notify() {
    local sensor=$1 val=$2 warn=$3 crit=$4 fan=${5:-"N/A"}
    [[ -z "$val" || "$val" == "N/A" ]] && return

    local status warn_count crit_count
    status=$(_get_state_value "$sensor" "status")
    warn_count=$(_get_state_value "$sensor" "warn_count")
    crit_count=$(_get_state_value "$sensor" "crit_count")

    [[ -z "$status" ]] && status="NORMAL"
    [[ -z "$warn_count" ]] && warn_count=0
    [[ -z "$crit_count" ]] && crit_count=0

    local reset_warn_threshold reset_crit_threshold
    reset_warn_threshold=$(awk "BEGIN{printf \"%.1f\", $warn - $ALERT_HYSTERESIS}")
    reset_crit_threshold=$(awk "BEGIN{printf \"%.1f\", $crit - $ALERT_HYSTERESIS}")

    if awk "BEGIN{exit !($val >= $crit)}"; then
        crit_count=$((crit_count + 1))
        warn_count=$((warn_count + 1))

        if [[ "$status" != "CRIT" ]]; then
            local needed
            needed=$(required_streak "$sensor" "CRIT")
            if (( crit_count >= needed )); then
                discord_notify "$sensor" "$val" "CRIT" "$fan"
                status="CRIT"
            fi
        fi

    elif awk "BEGIN{exit !($val >= $warn)}"; then
        warn_count=$((warn_count + 1))
        crit_count=0

        if [[ "$status" == "CRIT" ]]; then
            if awk "BEGIN{exit !($val <= $reset_crit_threshold)}"; then
                status="WARN"
            fi
        fi

        if [[ "$status" == "NORMAL" ]]; then
            local needed
            needed=$(required_streak "$sensor" "WARN")
            if (( warn_count >= needed )); then
                discord_notify "$sensor" "$val" "WARN" "$fan"
                status="WARN"
            fi
        fi

    else
        crit_count=0

        if [[ "$status" == "CRIT" ]]; then
            if awk "BEGIN{exit !($val <= $reset_crit_threshold)}"; then
                status="NORMAL"
                warn_count=0
            fi
        elif [[ "$status" == "WARN" ]]; then
            if awk "BEGIN{exit !($val <= $reset_warn_threshold)}"; then
                status="NORMAL"
                warn_count=0
            fi
        else
            warn_count=0
        fi
    fi

    _set_state "$sensor" "$status" "$warn_count" "$crit_count"
}

check_fan_stopped() {
    local fan=$1 gpu_temp=$2
    [[ -z "$fan" || "$fan" == "N/A" ]] && return
    [[ "$fan" != "0" ]] && return
    awk "BEGIN{exit !($gpu_temp >= $GPU_EDGE_WARN)}" || return
    discord_notify "GPU Fan" "$gpu_temp" "WARN" "0"
}

parse_sensors() {
    python3 -c "
import json, sys

raw = sys.stdin.read().strip()
if not raw:
    print('N/A N/A N/A N/A N/A N/A N/A N/A N/A N/A N/A')
    raise SystemExit(0)

try:
    data = json.loads(raw)
except Exception:
    print('N/A N/A N/A N/A N/A N/A N/A N/A N/A N/A N/A')
    raise SystemExit(0)

cpu = gpu_edge = gpu_jct = gpu_mem = gpu_fan = gpu_pwr = 'N/A'
eth = ssd = ram1 = ram2 = mb_fan = 'N/A'

for adapter, sensors in data.items():
    a = adapter.lower()

    if 'k10temp' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                cpu = f'{sdata[\"temp1_input\"]:.1f}'

    if 'nct6799' in a or 'isa-0290' in a:
        for sname, sdata in sensors.items():
            if not isinstance(sdata, dict):
                continue
            lower = sname.lower()
            if 'fan2' in lower and 'fan2_input' in sdata:
                mb_fan = f'{int(sdata[\"fan2_input\"])}'
                break
            if mb_fan == 'N/A':
                for key in ('fan1_input', 'fan2_input', 'fan3_input', 'fan4_input', 'fan5_input'):
                    if key in sdata:
                        try:
                            val = int(sdata[key])
                            if val > 0:
                                mb_fan = str(val)
                                break
                        except Exception:
                            pass

    if 'amdgpu' in a:
        for sname, sdata in sensors.items():
            if not isinstance(sdata, dict):
                continue
            s = sname.lower()

            if gpu_edge == 'N/A' and 'temp1_input' in sdata:
                if 'gpu integrada' in s or 'edge' in s or 'temp1' in s:
                    gpu_edge = f'{sdata[\"temp1_input\"]:.1f}'

            if gpu_jct == 'N/A':
                if s == 'junction' and 'temp2_input' in sdata:
                    gpu_jct = f'{sdata[\"temp2_input\"]:.1f}'
                elif 'junction' in s and 'temp2_input' in sdata:
                    gpu_jct = f'{sdata[\"temp2_input\"]:.1f}'
                elif 'temp2_input' in sdata:
                    gpu_jct = f'{sdata[\"temp2_input\"]:.1f}'

            if gpu_mem == 'N/A':
                if s == 'mem' and 'temp3_input' in sdata:
                    gpu_mem = f'{sdata[\"temp3_input\"]:.1f}'
                elif 'mem' in s and 'temp3_input' in sdata:
                    gpu_mem = f'{sdata[\"temp3_input\"]:.1f}'

            if gpu_fan == 'N/A':
                if s == 'fan1' and 'fan1_input' in sdata:
                    gpu_fan = f'{int(sdata[\"fan1_input\"])}'
                elif 'fan1_input' in sdata:
                    gpu_fan = f'{int(sdata[\"fan1_input\"])}'

            if gpu_pwr == 'N/A':
                if 'gpu power' in s and 'power1_average' in sdata:
                    gpu_pwr = f'{sdata[\"power1_average\"]:.1f}'
                elif 'power1_average' in sdata:
                    gpu_pwr = f'{sdata[\"power1_average\"]:.1f}'

    if 'r8169' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                eth = f'{sdata[\"temp1_input\"]:.1f}'

    if 'nvme' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                ssd = f'{sdata[\"temp1_input\"]:.1f}'
                break

    if 'spd5118' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                if ram1 == 'N/A':
                    ram1 = f'{sdata[\"temp1_input\"]:.1f}'
                else:
                    ram2 = f'{sdata[\"temp1_input\"]:.1f}'

print(cpu, gpu_edge, gpu_jct, gpu_mem, gpu_fan, gpu_pwr, eth, ssd, ram1, ram2, mb_fan)
"
}

render_ui() {
    local NOW=$1
    local CPU_TEMP=$2
    local GPU_EDGE=$3
    local GPU_JCT=$4
    local GPU_MEM=$5
    local GPU_FAN=$6
    local GPU_PWR=$7
    local ETH_TEMP=$8
    local SSD_TEMP=$9
    local RAM1=${10}
    local RAM2=${11}
    local MB_FAN=${12}

    tput civis 2>/dev/null || true
    clear || true

    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║            Monitor de Temperatura do Sistema         ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${DIM}Atualizado: ${NOW}   Intervalo: ${INTERVAL}s   (Ctrl+C para sair)${RESET}"
    echo ""

    echo -e "  ${BOLD}${CYAN}[ CPU — AMD Ryzen 5 9600X & Placa-Mãe ]${RESET}"
    echo -e "  ${DIM}Atenção: ${CPU_WARN}°C   Crítico: ${CPU_CRIT}°C (throttling em 95°C)${RESET}"
    echo ""
    [[ "$CPU_TEMP" != "N/A" ]] && sensor_line "CPU Core" "$CPU_TEMP" "$CPU_WARN" "$CPU_CRIT" 110
    if [[ "$MB_FAN" != "N/A" ]]; then
        printf "  ${DIM}%-26s${RESET} ${WHITE}%s RPM${RESET}\n" "Cooler (Placa-mãe):" "$MB_FAN"
    fi
    echo ""

    echo -e "  ${BOLD}${CYAN}[ GPU — AMD Radeon RX 7600 ]${RESET}"
    echo -e "  ${DIM}Edge warn: ${GPU_EDGE_WARN}°C   Junction warn: ${GPU_JCT_WARN}°C   Junction crit: ${GPU_JCT_CRIT}°C   Limite real: ${GPU_JCT_MAX}°C${RESET}"
    echo ""
    [[ "$GPU_EDGE" != "N/A" ]] && sensor_line "GPU Edge (global)"  "$GPU_EDGE" "$GPU_EDGE_WARN" "$GPU_EDGE_CRIT" 110
    [[ "$GPU_JCT"  != "N/A" ]] && sensor_line "GPU Junction (hot)" "$GPU_JCT"  "$GPU_JCT_WARN"  "$GPU_JCT_CRIT"  110
    [[ "$GPU_MEM"  != "N/A" ]] && sensor_line "GPU Memory (GDDR6)" "$GPU_MEM"  "$MEM_WARN"      "$MEM_CRIT"      105
    echo ""

    if [[ "$GPU_FAN" != "N/A" ]]; then
        if [[ "$GPU_FAN" == "0" ]]; then
            printf "  ${DIM}%-26s${RESET} ${YELLOW}0 RPM (parado/passivo)${RESET}\n" "Fan GPU:"
        else
            printf "  ${DIM}%-26s${RESET} ${WHITE}%s RPM${RESET}\n" "Fan GPU:" "$GPU_FAN"
        fi
    fi

    [[ "$GPU_PWR" != "N/A" ]] && \
        printf "  ${DIM}%-26s${RESET} ${WHITE}%s W${RESET}  ${DIM}(cap: 145W)${RESET}\n" "Consumo (PPT):" "$GPU_PWR"
    echo ""

    echo -e "  ${BOLD}${CYAN}[ RAM — DDR5 ]${RESET}"
    echo -e "  ${DIM}Atenção: ${RAM_WARN}°C   Crítico: ${RAM_CRIT}°C   Limite fabricante: 85°C${RESET}"
    echo ""
    [[ "$RAM1" != "N/A" ]] && sensor_line "Pente 1" "$RAM1" "$RAM_WARN" "$RAM_CRIT" 85
    [[ "$RAM2" != "N/A" ]] && sensor_line "Pente 2" "$RAM2" "$RAM_WARN" "$RAM_CRIT" 85
    echo ""

    echo -e "  ${BOLD}${CYAN}[ SSD — NVMe ]${RESET}"
    echo -e "  ${DIM}Atenção: ${SSD_WARN}°C   Crítico: ${SSD_CRIT}°C   Limite fabricante: 81°C${RESET}"
    echo ""
    [[ "$SSD_TEMP" != "N/A" ]] && sensor_line "SSD NVMe" "$SSD_TEMP" "$SSD_WARN" "$SSD_CRIT" 81
    echo ""

    echo -e "  ${BOLD}${CYAN}[ Rede — r8169 ]${RESET}"
    echo ""
    [[ "$ETH_TEMP" != "N/A" ]] && sensor_line "Ethernet" "$ETH_TEMP" 80 110 120
    echo ""

    if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
        echo -e "  ${DIM}Discord: ${GREEN}ativo${RESET}${DIM}  | cooldown: ${NOTIFY_COOLDOWN}s${RESET}"
        echo -e "  ${DIM}Persistência Junction: WARN=${GPU_JCT_WARN_STREAK_REQUIRED} | CRIT=${GPU_JCT_CRIT_STREAK_REQUIRED} leituras${RESET}"
    else
        echo -e "  ${DIM}Discord: desativado${RESET}"
    fi
    echo -e "  ${DIM}─────────────────────────────────────────────────────${RESET}"
    echo -e "  ${GREEN}[ OK ]${RESET} Normal   ${YELLOW}[WARN]${RESET} Atenção   ${BG_RED}${WHITE}[CRIT]${RESET} Crítico"
    echo ""

    tput cnorm 2>/dev/null || true
}

main_loop() {
    log_msg "INFO" "Iniciando sensors-monitor (daemon=$DAEMON_MODE, intervalo=${INTERVAL}s)"

    while true; do
        SENSORS_JSON=$(sensors -j 2>/dev/null || true)

        read -r CPU_TEMP GPU_EDGE GPU_JCT GPU_MEM GPU_FAN GPU_PWR ETH_TEMP SSD_TEMP RAM1 RAM2 MB_FAN \
            < <(parse_sensors <<< "$SENSORS_JSON")

        RAM_TEMP="N/A"
        if [[ "$RAM1" != "N/A" && "$RAM2" != "N/A" ]]; then
            RAM_TEMP=$(awk "BEGIN{printf \"%.1f\", ($RAM1 + $RAM2) / 2}")
        elif [[ "$RAM1" != "N/A" ]]; then
            RAM_TEMP="$RAM1"
        fi

        check_notify "CPU"          "$CPU_TEMP" "$CPU_WARN"      "$CPU_CRIT"
        check_notify "GPU Edge"     "$GPU_EDGE" "$GPU_EDGE_WARN" "$GPU_EDGE_CRIT" "$GPU_FAN"
        check_notify "GPU Junction" "$GPU_JCT"  "$GPU_JCT_WARN"  "$GPU_JCT_CRIT"  "$GPU_FAN"
        check_notify "GPU Memory"   "$GPU_MEM"  "$MEM_WARN"      "$MEM_CRIT"      "$GPU_FAN"
        check_notify "RAM DDR5"     "$RAM_TEMP" "$RAM_WARN"      "$RAM_CRIT"
        check_notify "SSD NVMe"     "$SSD_TEMP" "$SSD_WARN"      "$SSD_CRIT"

        [[ "$GPU_EDGE" != "N/A" ]] && check_fan_stopped "$GPU_FAN" "$GPU_EDGE"

        if [[ "$DAEMON_MODE" -eq 0 ]]; then
            NOW=$(date '+%d/%m/%Y %H:%M:%S')
            render_ui "$NOW" "$CPU_TEMP" "$GPU_EDGE" "$GPU_JCT" "$GPU_MEM" \
                      "$GPU_FAN" "$GPU_PWR" "$ETH_TEMP" "$SSD_TEMP" "$RAM1" "$RAM2" "$MB_FAN"
        fi

        sleep "$INTERVAL"
    done
}

main_loop
MONITOR_EOF

    chmod +x "$MONITOR_SCRIPT"
    success "Instalado em ${MONITOR_SCRIPT}"
}

# ─── Garante PATH ─────────────────────────────────────────────────────────────
ensure_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        local rc="$HOME/.bashrc"
        [[ "${SHELL:-}" == */zsh ]] && rc="$HOME/.zshrc"
        if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$rc" 2>/dev/null; then
            echo -e "\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$rc"
            warn "PATH atualizado em ${rc}. Execute: source ${rc}"
        fi
    fi
}

# ─── Teste de webhook ─────────────────────────────────────────────────────────
test_webhook() {
    [[ -z "${DISCORD_WEBHOOK:-}" ]] && return
    section "Teste de webhook"
    ask "Enviar mensagem de teste ao Discord? (s/N)"; read -r resp
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
            -X POST "$DISCORD_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"embeds\":[{
                \"title\":\"✅ sensors-monitor instalado!\",
                \"color\":3066993,
                \"fields\":[
                    {\"name\":\"Máquina\",          \"value\":\"\`${MACHINE_NAME}\`\",               \"inline\":true},
                    {\"name\":\"CPU warn/crit\",    \"value\":\"\`${CPU_WARN}°C / ${CPU_CRIT}°C\`\", \"inline\":true},
                    {\"name\":\"GPU Edge warn\",    \"value\":\"\`${GPU_EDGE_WARN}°C\`\",            \"inline\":true},
                    {\"name\":\"GPU Hotspot\",      \"value\":\"\`${GPU_JCT_WARN}°C / ${GPU_JCT_CRIT}°C\`\", \"inline\":true},
                    {\"name\":\"RAM warn/crit\",    \"value\":\"\`${RAM_WARN}°C / ${RAM_CRIT}°C\`\", \"inline\":true},
                    {\"name\":\"SSD warn/crit\",    \"value\":\"\`${SSD_WARN}°C / ${SSD_CRIT}°C\`\", \"inline\":true}
                ],
                \"footer\":{\"text\":\"sensors-monitor\"},
                \"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
            }]}")

        if [[ "$http_code" =~ ^2 ]]; then
            success "Mensagem de teste enviada! (HTTP ${http_code})"
        else
            error "Falha ao enviar. HTTP ${http_code} — verifique a URL do webhook."
        fi
    fi
}

# ─── Instala serviço user do systemd ──────────────────────────────────────────
install_user_service() {
    section "Instalando serviço do systemd (usuário)"

    mkdir -p "$USER_SYSTEMD_DIR"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Monitor de Sensores em Background (Discord Alerts)
After=network.target

[Service]
ExecStart=%h/.local/bin/sensors-monitor --daemon
Restart=always
RestartSec=10
StartLimitIntervalSec=60
StartLimitBurst=5

[Install]
WantedBy=default.target
EOF

    success "Serviço criado em ${SERVICE_FILE}"

    if systemctl --user daemon-reload; then
        success "systemd --user recarregado."
    else
        warn "Falha em daemon-reload do systemd --user."
    fi

    if systemctl --user enable sensors-monitor.service >/dev/null 2>&1; then
        success "Serviço habilitado para iniciar com a sessão."
    else
        warn "Não foi possível habilitar automaticamente."
    fi

    ask "Iniciar o serviço agora? (s/N)"; read -r resp
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        if systemctl --user start sensors-monitor.service; then
            success "Serviço iniciado."
        else
            error "Falha ao iniciar o serviço."
        fi
    fi

    echo ""
    info "Comandos úteis:"
    echo "  systemctl --user status sensors-monitor.service"
    echo "  journalctl --user -u sensors-monitor.service -f"
    echo "  systemctl --user restart sensors-monitor.service"
    echo "  systemctl --user stop sensors-monitor.service"
}

# ─── Finalização ──────────────────────────────────────────────────────────────
finish() {
    section "Tudo pronto!"
    echo -e "  Executar no terminal (modo visual):"
    echo ""
    echo -e "    ${BOLD}${GREEN}sensors-monitor${RESET}"
    echo ""
    echo -e "  Executar em background manualmente:"
    echo ""
    echo -e "    ${BOLD}${GREEN}sensors-monitor --daemon${RESET}"
    echo ""
    echo -e "  Para reconfigurar, edite:"
    echo -e "    ${DIM}${CONFIG_FILE}${RESET}"
    echo ""
    if [[ -f "$SERVICE_FILE" ]]; then
        echo -e "  Serviço user instalado em:"
        echo -e "    ${DIM}${SERVICE_FILE}${RESET}"
        echo ""
    fi
    echo -e "  ${YELLOW}${BOLD}Mudanças desta versão:${RESET}"
    echo -e "  ${DIM}• GPU Junction: warn 95°C / crit 105°C${RESET}"
    echo -e "  ${DIM}• Persistência por leituras seguidas para evitar spam${RESET}"
    echo -e "  ${DIM}• Histerese para não ficar alternando alerta/normal${RESET}"
    echo -e "  ${DIM}• Cooldown separado por sensor e nível${RESET}"
    echo -e "  ${DIM}• Alerta de fan parado quando GPU estiver quente${RESET}"
    echo ""
    echo -e "  ${YELLOW}${BOLD}Lembrete de segurança:${RESET}"
    echo -e "  ${DIM}O arquivo de configuração contém o webhook do Discord.${RESET}"
    echo -e "  ${DIM}Não o inclua em backups não criptografados ou repositórios Git.${RESET}"
    echo ""
    echo -e "  ${DIM}Cooldown persistido em: /tmp/sensors-monitor-cooldown/${RESET}"
    echo -e "  ${DIM}Estado persistido em:   /tmp/sensors-monitor-state/${RESET}"
    echo -e "  ${DIM}(limpos automaticamente no reboot da máquina)${RESET}"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
header
check_deps
configure
save_config
install_monitor
ensure_path
test_webhook

echo ""
ask "Instalar como serviço do usuário (systemd)? (s/N)"; read -r install_service
if [[ "$install_service" =~ ^[Ss]$ ]]; then
    install_user_service
fi

finish
