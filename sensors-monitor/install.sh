#!/usr/bin/env bash

# ─── Cores ───────────────────────────────────────────────────────────────────
RESET='\033[0m'; BOLD='\033[1m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
GREEN='\033[0;32m'; CYAN='\033[0;36m'; DIM='\033[2m'; WHITE='\033[1;37m'
BG_RED='\033[41m'

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/sensors-monitor"
CONFIG_FILE="$CONFIG_DIR/config.env"
MONITOR_SCRIPT="$INSTALL_DIR/sensors-monitor"

info()    { echo -e "  ${CYAN}${BOLD}→${RESET} $1"; }
success() { echo -e "  ${GREEN}${BOLD}✓${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}${BOLD}!${RESET} $1"; }
error()   { echo -e "  ${RED}${BOLD}✗${RESET} $1"; }
ask()     { echo -ne "  ${WHITE}${BOLD}?${RESET} $1 "; }

header() {
    clear
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
    for cmd in sensors python3 curl bc; do
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
        ask "Instalar automaticamente? (s/N)"; read -r resp
        if [[ "$resp" =~ ^[Ss]$ ]]; then
            sudo apt-get update -qq
            for pkg in "${missing[@]}"; do
                [[ "$pkg" == "sensors" ]] && pkg="lm-sensors"
                sudo apt-get install -y "$pkg"
            done
            success "Dependências instaladas."
        else
            error "Instale as dependências e execute o install novamente."
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
    info "Limiares recomendados para seu hardware (Ryzen 5 9600X + RX 7600 + DDR5)."
    ask "Usar limiares recomendados? (S/n)"; read -r use_defaults

    if [[ "$use_defaults" =~ ^[Nn]$ ]]; then
        ask "CPU ATENÇÃO °C       (padrão: 85):"; read -r CPU_WARN;      CPU_WARN=${CPU_WARN:-85}
        ask "CPU CRÍTICO °C       (padrão: 92):"; read -r CPU_CRIT;      CPU_CRIT=${CPU_CRIT:-92}
        ask "GPU Edge ATENÇÃO °C  (padrão: 80):"; read -r GPU_EDGE_WARN; GPU_EDGE_WARN=${GPU_EDGE_WARN:-80}
        ask "GPU Edge CRÍTICO °C  (padrão: 90):"; read -r GPU_EDGE_CRIT; GPU_EDGE_CRIT=${GPU_EDGE_CRIT:-90}
        ask "GPU Hotspot ATENÇÃO °C (padrão: 85):"; read -r GPU_JCT_WARN; GPU_JCT_WARN=${GPU_JCT_WARN:-85}
        ask "GPU Hotspot CRÍTICO °C (padrão: 95):"; read -r GPU_JCT_CRIT; GPU_JCT_CRIT=${GPU_JCT_CRIT:-95}
        ask "RAM ATENÇÃO °C       (padrão: 50):"; read -r RAM_WARN;      RAM_WARN=${RAM_WARN:-50}
        ask "RAM CRÍTICO °C       (padrão: 75):"; read -r RAM_CRIT;      RAM_CRIT=${RAM_CRIT:-75}
        ask "SSD ATENÇÃO °C       (padrão: 60):"; read -r SSD_WARN;      SSD_WARN=${SSD_WARN:-60}
        ask "SSD CRÍTICO °C       (padrão: 75):"; read -r SSD_CRIT;      SSD_CRIT=${SSD_CRIT:-75}
    else
        CPU_WARN=85;      CPU_CRIT=92
        GPU_EDGE_WARN=80; GPU_EDGE_CRIT=90
        GPU_JCT_WARN=85;  GPU_JCT_CRIT=95
        RAM_WARN=50;      RAM_CRIT=75
        SSD_WARN=60;      SSD_CRIT=75
        success "Limiares recomendados aplicados."
    fi

    echo ""
    ask "Intervalo de atualização em segundos (padrão: 2):";          read -r INTERVAL;        INTERVAL=${INTERVAL:-2}
    ask "Cooldown entre alertas Discord em segundos (padrão: 300):";  read -r NOTIFY_COOLDOWN; NOTIFY_COOLDOWN=${NOTIFY_COOLDOWN:-300}
    ask "Nome desta máquina no Discord (padrão: $(hostname)):";       read -r MACHINE_NAME;    MACHINE_NAME=${MACHINE_NAME:-$(hostname)}

    echo ""
    success "Configuração concluída."
}

# ─── Salva config ─────────────────────────────────────────────────────────────
save_config() {
    section "Salvando configuração"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
# sensors-monitor — gerado em $(date)
DISCORD_WEBHOOK="${DISCORD_WEBHOOK}"

# CPU — AMD Ryzen 5 9600X (throttling em 95°C)
CPU_WARN=${CPU_WARN}
CPU_CRIT=${CPU_CRIT}

# GPU Edge — AMD RX 7600
GPU_EDGE_WARN=${GPU_EDGE_WARN}
GPU_EDGE_CRIT=${GPU_EDGE_CRIT}

# GPU Junction/Hotspot — AMD RX 7600 (limite real: 110°C)
GPU_JCT_WARN=${GPU_JCT_WARN}
GPU_JCT_CRIT=${GPU_JCT_CRIT}

# GPU Memory — AMD RX 7600 (limite real: 105°C)
MEM_WARN=85
MEM_CRIT=100

# RAM DDR5
RAM_WARN=${RAM_WARN}
RAM_CRIT=${RAM_CRIT}

# SSD NVMe (crítico fabricante: 81°C)
SSD_WARN=${SSD_WARN}
SSD_CRIT=${SSD_CRIT}

INTERVAL=${INTERVAL}
NOTIFY_COOLDOWN=${NOTIFY_COOLDOWN}
MACHINE_NAME="${MACHINE_NAME}"
EOF
    chmod 600 "$CONFIG_FILE"
    success "Salvo em ${CONFIG_FILE}"
}

# ─── Instala script principal ─────────────────────────────────────────────────
install_monitor() {
    section "Instalando sensors-monitor"
    mkdir -p "$INSTALL_DIR"

    cat > "$MONITOR_SCRIPT" <<'EOF'
#!/usr/bin/env bash

CONFIG="$HOME/.config/sensors-monitor/config.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

INTERVAL=${INTERVAL:-2}
CPU_WARN=${CPU_WARN:-85};         CPU_CRIT=${CPU_CRIT:-92}
GPU_EDGE_WARN=${GPU_EDGE_WARN:-80}; GPU_EDGE_CRIT=${GPU_EDGE_CRIT:-90}
GPU_JCT_WARN=${GPU_JCT_WARN:-85};  GPU_JCT_CRIT=${GPU_JCT_CRIT:-95}
MEM_WARN=${MEM_WARN:-85};          MEM_CRIT=${MEM_CRIT:-100}
RAM_WARN=${RAM_WARN:-50};          RAM_CRIT=${RAM_CRIT:-75}
SSD_WARN=${SSD_WARN:-60};          SSD_CRIT=${SSD_CRIT:-75}
NOTIFY_COOLDOWN=${NOTIFY_COOLDOWN:-300}
MACHINE_NAME=${MACHINE_NAME:-$(hostname)}

RESET='\033[0m'; BOLD='\033[1m'; YELLOW='\033[0;33m'
GREEN='\033[0;32m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'
DIM='\033[2m'; BG_RED='\033[41m'

declare -A LAST_NOTIFIED

temp_color() {
    local v=$1 w=$2 c=$3
    (( $(echo "$v >= $c" | bc -l) )) && { echo -e "${BG_RED}${WHITE}"; return; }
    (( $(echo "$v >= $w" | bc -l) )) && { echo -e "${YELLOW}"; return; }
    echo -e "${GREEN}"
}

draw_bar() {
    local v=$1 max=$2 w=$3 c=$4 width=30
    local filled=$(echo "scale=0; ($v * $width) / $max" | bc)
    local color=$(temp_color "$v" "$w" "$c") bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<width; i++)); do bar+="░"; done
    echo -e "${color}${bar}${RESET}"
}

sensor_line() {
    local label=$1 v=$2 w=$3 c=$4 max=${5:-110}
    local color=$(temp_color "$v" "$w" "$c")
    local bar=$(draw_bar "$v" "$max" "$w" "$c")
    local icon="[ OK ]"
    (( $(echo "$v >= $c" | bc -l) )) && icon="[CRIT]" || \
    (( $(echo "$v >= $w" | bc -l) )) && icon="[WARN]"
    printf "  ${DIM}%-26s${RESET} %s %s ${color}%s°C${RESET}\n" \
        "$label" "$bar" "${color}${icon}${RESET}" "$v"
}

build_discord_context() {
    local sensor=$1 level=$2 fan=$3
    local context="" fan_info=""

    [[ -n "$fan" && "$fan" != "N/A" && "$fan" != "0" ]] && fan_info="**Fan GPU:** \`${fan} RPM\`"
    [[ "$fan" == "0" ]] && fan_info="**Fan GPU:** \`0 RPM — cooler parado ou passivo\`"

    case "$sensor" in
        "CPU")
            [[ "$level" == "CRIT" ]] \
                && context="Você está a 3°C do throttling oficial AMD (95°C). Performance pode ser reduzida automaticamente." \
                || context="Carga alta no Zen 5. Normal para picos, mas o sistema está sendo bastante exigido."
            ;;
        "GPU Edge")
            [[ "$level" == "CRIT" ]] \
                && context="Temperatura global da RX 7600 acima do esperado. Verifique o fluxo de ar do gabinete." \
                || context="A RX 7600 costuma operar abaixo de 80°C. Fluxo de ar do gabinete pode estar insuficiente."
            ;;
        "GPU Junction")
            [[ "$level" == "CRIT" ]] \
                && context="Hotspot a 15°C do limite real (110°C). Ponto mais quente do die — monitore de perto." \
                || context="Hotspot elevado. Limite real da RX 7600 é 110°C, mas atenção ao fluxo de ar."
            ;;
        "GPU Memory")
            context="Memória GDDR6 elevada. Verifique o fluxo de ar sobre a GPU."
            ;;
        "RAM DDR5")
            [[ "$level" == "CRIT" ]] \
                && context="Temperatura da RAM DDR5 crítica. Verifique o fluxo de ar no gabinete e XMP/EXPO." \
                || context="RAM DDR5 aquecendo. Limite do fabricante é 85°C."
            ;;
        "SSD NVMe")
            [[ "$level" == "CRIT" ]] \
                && context="SSD próximo do limite crítico do fabricante (81°C). Pode ocorrer throttling de leitura/escrita." \
                || context="SSD aquecendo. Acima de 75°C pode haver redução de performance."
            ;;
    esac

    echo "${context}|${fan_info}"
}

discord_notify() {
    local sensor=$1 val=$2 level=$3 fan=${4:-"N/A"}
    [[ -z "$DISCORD_WEBHOOK" ]] && return

    local now=$(date +%s) last=${LAST_NOTIFIED[$sensor]:-0}
    (( now - last < NOTIFY_COOLDOWN )) && return
    LAST_NOTIFIED[$sensor]=$now

    local color=16776960 emoji="🟡" title="Temperatura elevada"
    [[ "$level" == "CRIT" ]] && color=15158332 && emoji="🔴" && title="TEMPERATURA CRÍTICA"

    local raw; raw=$(build_discord_context "$sensor" "$level" "$fan")
    local context="${raw%%|*}"
    local fan_info="${raw##*|}"

    local fields="[
        {\"name\":\"Máquina\",\"value\":\"\`${MACHINE_NAME}\`\",\"inline\":true},
        {\"name\":\"Sensor\",\"value\":\"\`${sensor}\`\",\"inline\":true},
        {\"name\":\"Leitura\",\"value\":\"\`${val}°C\`\",\"inline\":true}"
    [[ -n "$fan_info" ]] && fields+=",{\"name\":\"Cooler\",\"value\":\"${fan_info}\",\"inline\":false}"
    [[ -n "$context"  ]] && fields+=",{\"name\":\"Diagnóstico\",\"value\":\"${context}\",\"inline\":false}"
    fields+="]"

    curl -s -X POST "$DISCORD_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"embeds\":[{
            \"title\":\"${emoji} ${title}\",
            \"color\":${color},
            \"fields\":${fields},
            \"footer\":{\"text\":\"sensors-monitor • ${MACHINE_NAME}\"},
            \"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        }]}" > /dev/null
}

check_notify() {
    local sensor=$1 val=$2 w=$3 c=$4 fan=${5:-"N/A"}
    [[ -z "$val" || "$val" == "N/A" ]] && return
    if (( $(echo "$val >= $c" | bc -l) )); then
        discord_notify "$sensor" "$val" "CRIT" "$fan"
    elif (( $(echo "$val >= $w" | bc -l) )); then
        discord_notify "$sensor" "$val" "WARN" "$fan"
    fi
}

# ─── Parser corrigido baseado no JSON real ───────────────────────────────────
parse_sensors() {
    python3 -c "
import json, sys

data = json.loads(sys.stdin.read())

cpu = gpu_edge = gpu_jct = gpu_mem = gpu_fan = gpu_pwr = 'N/A'
eth = ssd = ram1 = ram2 = 'N/A'

for adapter, sensors in data.items():
    a = adapter.lower()

    # CPU — k10temp, campo 'CPU Ryzen 5 9600X' > temp1_input
    if 'k10temp' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                cpu = f\"{sdata['temp1_input']:.1f}\"

    # GPU RX 7600 — amdgpu-pci-0300 (tem fan e power1_average)
    if 'amdgpu-pci-0300' in a:
        for sname, sdata in sensors.items():
            if not isinstance(sdata, dict): continue
            s = sname.lower()
            # Edge
            if 'gpu integrada' in sname.lower() and 'temp1_input' in sdata:
                gpu_edge = f\"{sdata['temp1_input']:.1f}\"
            # Junction
            if s == 'junction' and 'temp2_input' in sdata:
                gpu_jct = f\"{sdata['temp2_input']:.1f}\"
            # Memory
            if s == 'mem' and 'temp3_input' in sdata:
                gpu_mem = f\"{sdata['temp3_input']:.1f}\"
            # Fan — está em sname='fan1', campo fan1_input
            if s == 'fan1' and 'fan1_input' in sdata:
                gpu_fan = f\"{int(sdata['fan1_input'])}\"
            # Power — power1_average (não power1_input)
            if 'gpu power' in sname.lower() and 'power1_average' in sdata:
                gpu_pwr = f\"{sdata['power1_average']:.1f}\"

    # Ethernet
    if 'r8169' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                eth = f\"{sdata['temp1_input']:.1f}\"

    # SSD NVMe
    if 'nvme' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                ssd = f\"{sdata['temp1_input']:.1f}\"
                break

    # RAM DDR5 — dois pentes (spd5118)
    if 'spd5118' in a:
        for sname, sdata in sensors.items():
            if isinstance(sdata, dict) and 'temp1_input' in sdata:
                if ram1 == 'N/A':
                    ram1 = f\"{sdata['temp1_input']:.1f}\"
                else:
                    ram2 = f\"{sdata['temp1_input']:.1f}\"

print(cpu, gpu_edge, gpu_jct, gpu_mem, gpu_fan, gpu_pwr, eth, ssd, ram1, ram2)
"
}

while true; do
    clear
    SENSORS_JSON=$(sensors -j 2>/dev/null)
    read -r CPU_TEMP GPU_EDGE GPU_JCT GPU_MEM GPU_FAN GPU_PWR ETH_TEMP SSD_TEMP RAM1 RAM2 \
        < <(parse_sensors <<< "$SENSORS_JSON")

    # Média dos dois pentes de RAM
    RAM_TEMP="N/A"
    if [[ "$RAM1" != "N/A" && "$RAM2" != "N/A" ]]; then
        RAM_TEMP=$(echo "scale=1; ($RAM1 + $RAM2) / 2" | bc)
    elif [[ "$RAM1" != "N/A" ]]; then
        RAM_TEMP="$RAM1"
    fi

    # Notificações Discord
    check_notify "CPU"          "$CPU_TEMP" "$CPU_WARN"      "$CPU_CRIT"      "$GPU_FAN"
    check_notify "GPU Edge"     "$GPU_EDGE" "$GPU_EDGE_WARN" "$GPU_EDGE_CRIT" "$GPU_FAN"
    check_notify "GPU Junction" "$GPU_JCT"  "$GPU_JCT_WARN"  "$GPU_JCT_CRIT"  "$GPU_FAN"
    check_notify "GPU Memory"   "$GPU_MEM"  "$MEM_WARN"      "$MEM_CRIT"      "$GPU_FAN"
    check_notify "RAM DDR5"     "$RAM_TEMP" "$RAM_WARN"      "$RAM_CRIT"
    check_notify "SSD NVMe"     "$SSD_TEMP" "$SSD_WARN"      "$SSD_CRIT"

    NOW=$(date '+%d/%m/%Y %H:%M:%S')

    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║           Monitor de Temperatura do Sistema          ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${DIM}Atualizado: ${NOW}   Intervalo: ${INTERVAL}s   (Ctrl+C para sair)${RESET}"
    echo ""

    # ── CPU ──
    echo -e "  ${BOLD}${CYAN}[ CPU — AMD Ryzen 5 9600X ]${RESET}"
    echo -e "  ${DIM}Atenção: ${CPU_WARN}°C   Crítico: ${CPU_CRIT}°C (throttling em 95°C)${RESET}"
    echo ""
    [[ "$CPU_TEMP" != "N/A" ]] && sensor_line "CPU Core" "$CPU_TEMP" "$CPU_WARN" "$CPU_CRIT" 110
    echo ""

    # ── GPU ──
    echo -e "  ${BOLD}${CYAN}[ GPU — AMD Radeon RX 7600 ]${RESET}"
    echo -e "  ${DIM}Edge warn: ${GPU_EDGE_WARN}°C   Junction crit: ${GPU_JCT_CRIT}°C   Limite real: 110°C${RESET}"
    echo ""
    [[ "$GPU_EDGE" != "N/A" ]] && sensor_line "GPU Edge (global)"  "$GPU_EDGE" "$GPU_EDGE_WARN" "$GPU_EDGE_CRIT" 110
    [[ "$GPU_JCT"  != "N/A" ]] && sensor_line "GPU Junction (hot)" "$GPU_JCT"  "$GPU_JCT_WARN"  "$GPU_JCT_CRIT"  110
    [[ "$GPU_MEM"  != "N/A" ]] && sensor_line "GPU Memory (GDDR6)" "$GPU_MEM"  "$MEM_WARN"      "$MEM_CRIT"      105
    echo ""

    # Fan e consumo GPU
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

    # ── RAM ──
    echo -e "  ${BOLD}${CYAN}[ RAM — DDR5 ]${RESET}"
    echo -e "  ${DIM}Atenção: ${RAM_WARN}°C   Crítico: ${RAM_CRIT}°C   Limite fabricante: 85°C${RESET}"
    echo ""
    [[ "$RAM1" != "N/A" ]] && sensor_line "Pente 1" "$RAM1" "$RAM_WARN" "$RAM_CRIT" 85
    [[ "$RAM2" != "N/A" ]] && sensor_line "Pente 2" "$RAM2" "$RAM_WARN" "$RAM_CRIT" 85
    echo ""

    # ── SSD ──
    echo -e "  ${BOLD}${CYAN}[ SSD — NVMe ]${RESET}"
    echo -e "  ${DIM}Atenção: ${SSD_WARN}°C   Crítico: ${SSD_CRIT}°C   Limite fabricante: 81°C${RESET}"
    echo ""
    [[ "$SSD_TEMP" != "N/A" ]] && sensor_line "SSD NVMe" "$SSD_TEMP" "$SSD_WARN" "$SSD_CRIT" 81
    echo ""

    # ── Rede ──
    echo -e "  ${BOLD}${CYAN}[ Rede — r8169 ]${RESET}"
    echo ""
    [[ "$ETH_TEMP" != "N/A" ]] && sensor_line "Ethernet" "$ETH_TEMP" 80 110 120
    echo ""

    # Rodapé
    if [[ -n "$DISCORD_WEBHOOK" ]]; then
        echo -e "  ${DIM}Discord: ${GREEN}ativo${RESET}${DIM}  |  cooldown: ${NOTIFY_COOLDOWN}s${RESET}"
    else
        echo -e "  ${DIM}Discord: desativado${RESET}"
    fi
    echo -e "  ${DIM}─────────────────────────────────────────────────────${RESET}"
    echo -e "  ${GREEN}[ OK ]${RESET} Normal   ${YELLOW}[WARN]${RESET} Atenção   ${BG_RED}${WHITE}[CRIT]${RESET} Crítico"
    echo ""

    sleep "$INTERVAL"
done
EOF

    chmod +x "$MONITOR_SCRIPT"
    success "Instalado em ${MONITOR_SCRIPT}"
}

# ─── Garante PATH ─────────────────────────────────────────────────────────────
ensure_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        local rc="$HOME/.bashrc"
        [[ "$SHELL" == */zsh ]] && rc="$HOME/.zshrc"
        echo -e "\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$rc"
        warn "PATH atualizado em ${rc}. Execute: source ${rc}"
    fi
}

# ─── Teste de webhook ─────────────────────────────────────────────────────────
test_webhook() {
    [[ -z "$DISCORD_WEBHOOK" ]] && return
    section "Teste de webhook"
    ask "Enviar mensagem de teste ao Discord? (s/N)"; read -r resp
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        curl -s -X POST "$DISCORD_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"embeds\":[{
                \"title\":\"✅ sensors-monitor instalado!\",
                \"color\":3066993,
                \"fields\":[
                    {\"name\":\"Máquina\",         \"value\":\"\`${MACHINE_NAME}\`\",                        \"inline\":true},
                    {\"name\":\"CPU warn/crit\",    \"value\":\"\`${CPU_WARN}°C / ${CPU_CRIT}°C\`\",          \"inline\":true},
                    {\"name\":\"GPU Edge warn\",    \"value\":\"\`${GPU_EDGE_WARN}°C\`\",                     \"inline\":true},
                    {\"name\":\"GPU Hotspot crit\", \"value\":\"\`${GPU_JCT_CRIT}°C\`\",                     \"inline\":true},
                    {\"name\":\"RAM warn/crit\",    \"value\":\"\`${RAM_WARN}°C / ${RAM_CRIT}°C\`\",          \"inline\":true},
                    {\"name\":\"SSD warn/crit\",    \"value\":\"\`${SSD_WARN}°C / ${SSD_CRIT}°C\`\",          \"inline\":true}
                ],
                \"footer\":{\"text\":\"sensors-monitor\"},
                \"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
            }]}" > /dev/null \
            && success "Mensagem de teste enviada!" \
            || error "Falha ao enviar. Verifique a URL do webhook."
    fi
}

# ─── Finalização ──────────────────────────────────────────────────────────────
finish() {
    section "Tudo pronto!"
    echo -e "  Execute para iniciar:"
    echo ""
    echo -e "    ${BOLD}${GREEN}sensors-monitor${RESET}"
    echo ""
    echo -e "  Para reconfigurar, edite:"
    echo -e "    ${DIM}${CONFIG_FILE}${RESET}"
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
finish
