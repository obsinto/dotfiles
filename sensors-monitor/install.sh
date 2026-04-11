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
    info "Limiares padrão já configurados para seu hardware (Ryzen 5 9600X + RX 7600)."
    ask "Usar limiares recomendados? (S/n)"; read -r use_defaults

    if [[ "$use_defaults" =~ ^[Nn]$ ]]; then
        ask "CPU ATENÇÃO °C  (padrão: 85):";  read -r CPU_WARN;     CPU_WARN=${CPU_WARN:-85}
        ask "CPU CRÍTICO °C  (padrão: 92):";  read -r CPU_CRIT;     CPU_CRIT=${CPU_CRIT:-92}
        ask "GPU Edge ATENÇÃO °C (padrão: 80):"; read -r GPU_WARN;  GPU_WARN=${GPU_WARN:-80}
        ask "GPU Hotspot CRÍTICO °C (padrão: 95):"; read -r GPU_JCT_CRIT; GPU_JCT_CRIT=${GPU_JCT_CRIT:-95}
    else
        CPU_WARN=85; CPU_CRIT=92
        GPU_WARN=80; GPU_JCT_CRIT=95
        success "Limiares recomendados aplicados."
    fi

    echo ""
    ask "Intervalo de atualização em segundos (padrão: 2):"; read -r INTERVAL; INTERVAL=${INTERVAL:-2}
    ask "Cooldown entre alertas Discord em segundos (padrão: 300):"; read -r NOTIFY_COOLDOWN; NOTIFY_COOLDOWN=${NOTIFY_COOLDOWN:-300}
    ask "Nome desta máquina no Discord (padrão: $(hostname)):"; read -r MACHINE_NAME; MACHINE_NAME=${MACHINE_NAME:-$(hostname)}

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

# CPU — AMD Ryzen 5 9600X
# 85°C: Carga alta, normal para picos Zen 5
# 92°C: A 3°C do throttling oficial AMD (95°C)
CPU_WARN=${CPU_WARN}
CPU_CRIT=${CPU_CRIT}

# GPU Edge — AMD RX 7600
# 80°C: Fluxo de ar do gabinete pode estar insuficiente
GPU_EDGE_WARN=${GPU_WARN}
GPU_EDGE_CRIT=90

# GPU Hotspot / Junction — AMD RX 7600
# 95°C: Margem de 15°C antes do limite real (110°C)
GPU_JCT_WARN=85
GPU_JCT_CRIT=${GPU_JCT_CRIT}

# GPU Memory
MEM_WARN=85
MEM_CRIT=100

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

# ─── Monta mensagem de contexto para o Discord ───────────────────────────────
build_discord_context() {
    local sensor=$1 val=$2 level=$3 fan_speed=$4

    local context=""
    local fan_info=""

    # Info da fan
    if [[ -n "$fan_speed" && "$fan_speed" != "N/A" && "$fan_speed" != "0" ]]; then
        fan_info="**Fan:** \`${fan_speed} RPM\`"
    elif [[ "$fan_speed" == "0" ]]; then
        fan_info="**Fan:** \`0 RPM — cooler parado ou passivo\`"
    fi

    # Contexto específico por sensor e nível
    case "$sensor" in
        "CPU")
            if [[ "$level" == "CRIT" ]]; then
                context="Você está a 3°C do throttling oficial AMD (95°C). Performance pode ser reduzida automaticamente. Verifique o cooler e o fluxo de ar."
            else
                context="Carga alta detectada. Normal para picos de processamento no Zen 5, mas indica que o sistema está sendo bastante exigido."
            fi
            ;;
        "GPU Edge")
            if [[ "$level" == "CRIT" ]]; then
                context="Temperatura global da GPU acima do esperado para a RX 7600. Verifique o fluxo de ar do gabinete urgentemente."
            else
                context="A RX 7600 costuma operar abaixo de 80°C. Se bater esse valor, o fluxo de ar do gabinete pode estar insuficiente."
            fi
            ;;
        "GPU Junction")
            if [[ "$level" == "CRIT" ]]; then
                context="Hotspot a 15°C do limite real da RX 7600 (110°C). Ponto mais quente do die — monitore de perto."
            else
                context="Hotspot elevado. As GPUs AMD suportam até 110°C no Junction, mas atenção ao fluxo de ar e pasta térmica."
            fi
            ;;
        "GPU Memory")
            context="Temperatura da memória GDDR6 elevada. Verifique o fluxo de ar sobre a GPU."
            ;;
    esac

    echo "${context}|${fan_info}"
}

# ─── Envia alerta ao Discord ─────────────────────────────────────────────────
discord_notify() {
    local sensor=$1 val=$2 level=$3 fan_speed=${4:-"N/A"}
    [[ -z "$DISCORD_WEBHOOK" ]] && return

    local now=$(date +%s) last=${LAST_NOTIFIED[$sensor]:-0}
    (( now - last < NOTIFY_COOLDOWN )) && return
    LAST_NOTIFIED[$sensor]=$now

    local color=16776960 emoji="🟡" title="Temperatura elevada"
    [[ "$level" == "CRIT" ]] && color=15158332 && emoji="🔴" && title="TEMPERATURA CRÍTICA"

    local raw_context
    raw_context=$(build_discord_context "$sensor" "$val" "$level" "$fan_speed")
    local context="${raw_context%%|*}"
    local fan_info="${raw_context##*|}"

    # Monta fields dinamicamente
    local fields="[
        {\"name\":\"Máquina\",\"value\":\"\`${MACHINE_NAME}\`\",\"inline\":true},
        {\"name\":\"Sensor\",\"value\":\"\`${sensor}\`\",\"inline\":true},
        {\"name\":\"Leitura\",\"value\":\"\`${val}°C\`\",\"inline\":true}"

    [[ -n "$fan_info" ]] && fields+=",{\"name\":\"Velocidade do Cooler\",\"value\":\"${fan_info}\",\"inline\":false}"
    [[ -n "$context"  ]] && fields+=",{\"name\":\"Diagnóstico\",\"value\":\"${context}\",\"inline\":false}"

    fields+="]"

    curl -s -X POST "$DISCORD_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"embeds\":[{
            \"title\":\"${emoji} ${title}\",
            \"color\":${color},
            \"fields\":${fields},
            \"footer\":{\"text\":\"sensors-monitor • $(hostname)\"},
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

parse_sensors() {
    python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
cpu = gpu = jct = mem = eth = fan = pwr = 'N/A'
for adapter, sensors in data.items():
    a = adapter.lower()
    for sname, sdata in sensors.items():
        if not isinstance(sdata, dict): continue
        for key, val in sdata.items():
            k = key.lower()
            if 'k10temp' in a and 'temp1_input' in k: cpu = f'{val:.1f}'
            if 'amdgpu' in a:
                if   'temp1_input'  in k: gpu = f'{val:.1f}'
                elif 'temp2_input'  in k: jct = f'{val:.1f}'
                elif 'temp3_input'  in k: mem = f'{val:.1f}'
                elif 'fan1_input'   in k: fan = f'{int(val)}'
                elif 'power1_input' in k: pwr = f'{val:.1f}'
            if 'r8169' in a and 'temp1_input' in k: eth = f'{val:.1f}'
print(cpu, gpu, jct, mem, eth, fan, pwr)
"
}

while true; do
    clear
    SENSORS_JSON=$(sensors -j 2>/dev/null)
    read -r CPU_TEMP GPU_TEMP GPU_JCT GPU_MEM ETH_TEMP GPU_FAN GPU_POWER \
        < <(parse_sensors <<< "$SENSORS_JSON")

    # Notificações com fan speed incluída no contexto
    check_notify "CPU"          "$CPU_TEMP" "$CPU_WARN"      "$CPU_CRIT"      "$GPU_FAN"
    check_notify "GPU Edge"     "$GPU_TEMP" "$GPU_EDGE_WARN" "$GPU_EDGE_CRIT" "$GPU_FAN"
    check_notify "GPU Junction" "$GPU_JCT"  "$GPU_JCT_WARN"  "$GPU_JCT_CRIT"  "$GPU_FAN"
    check_notify "GPU Memory"   "$GPU_MEM"  "$MEM_WARN"      "$MEM_CRIT"      "$GPU_FAN"

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
    echo -e "  ${DIM}Atenção: ${CPU_WARN}°C (carga alta)   Crítico: ${CPU_CRIT}°C (a 3°C do throttling)${RESET}"
    echo ""
    [[ -n "$CPU_TEMP" && "$CPU_TEMP" != "N/A" ]] && \
        sensor_line "CPU Core" "$CPU_TEMP" "$CPU_WARN" "$CPU_CRIT" 110
    echo ""

    # ── GPU ──
    echo -e "  ${BOLD}${CYAN}[ GPU — AMD Radeon RX 7600 ]${RESET}"
    echo -e "  ${DIM}Edge: atenção ${GPU_EDGE_WARN}°C   Junction: crítico ${GPU_JCT_CRIT}°C (limite real: 110°C)${RESET}"
    echo ""
    [[ -n "$GPU_TEMP" && "$GPU_TEMP" != "N/A" ]] && \
        sensor_line "GPU Edge (global)"   "$GPU_TEMP" "$GPU_EDGE_WARN" "$GPU_EDGE_CRIT" 110
    [[ -n "$GPU_JCT"  && "$GPU_JCT"  != "N/A" ]] && \
        sensor_line "GPU Junction (hot)"  "$GPU_JCT"  "$GPU_JCT_WARN"  "$GPU_JCT_CRIT"  110
    [[ -n "$GPU_MEM"  && "$GPU_MEM"  != "N/A" ]] && \
        sensor_line "GPU Memory (GDDR6)"  "$GPU_MEM"  "$MEM_WARN"      "$MEM_CRIT"      105
    echo ""

    # Fan e consumo
    if [[ -n "$GPU_FAN" && "$GPU_FAN" != "N/A" ]]; then
        if [[ "$GPU_FAN" == "0" ]]; then
            printf "  ${DIM}%-26s${RESET} ${YELLOW}0 RPM (parado/passivo)${RESET}\n" "Fan GPU:"
        else
            printf "  ${DIM}%-26s${RESET} ${WHITE}%s RPM${RESET}\n" "Fan GPU:" "$GPU_FAN"
        fi
    fi
    [[ -n "$GPU_POWER" && "$GPU_POWER" != "N/A" ]] && \
        printf "  ${DIM}%-26s${RESET} ${WHITE}%s W${RESET}  ${DIM}(cap: 165W)${RESET}\n" "Consumo (PPT):" "$GPU_POWER"
    echo ""

    # ── Rede ──
    echo -e "  ${BOLD}${CYAN}[ Rede — r8169 ]${RESET}"; echo ""
    [[ -n "$ETH_TEMP" && "$ETH_TEMP" != "N/A" ]] && \
        sensor_line "Ethernet" "$ETH_TEMP" 80 110 120
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
                    {\"name\":\"Máquina\",\"value\":\"\`${MACHINE_NAME}\`\",\"inline\":true},
                    {\"name\":\"CPU warn/crit\",\"value\":\"\`${CPU_WARN}°C / ${CPU_CRIT}°C\`\",\"inline\":true},
                    {\"name\":\"GPU Edge warn\",\"value\":\"\`${GPU_WARN}°C\`\",\"inline\":true},
                    {\"name\":\"GPU Junction crit\",\"value\":\"\`${GPU_JCT_CRIT}°C\`\",\"inline\":true}
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
