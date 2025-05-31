#!/bin/bash

# ============================================================================
# 🚀 INSTALADOR COMPLETO DO TERMINAL
# Configuração automática: Zsh + Oh My Zsh + Powerlevel10k + WezTerm
# Baseado nas configurações atuais do usuário
# ============================================================================

set -e  # Para em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "\n${BLUE}====== $1 ======${NC}\n"
}

# Detectar distribuição
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        error "Não foi possível detectar a distribuição Linux"
        exit 1
    fi
}

# Instalar dependências baseado na distro
install_dependencies() {
    header "Instalando dependências básicas"
    
    case $DISTRO in
        ubuntu|debian|pop)
            sudo apt update
            sudo apt install -y git curl zsh wget fontconfig unzip
            ;;
        fedora)
            sudo dnf install -y git curl zsh wget fontconfig unzip
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm git curl zsh wget fontconfig unzip
            ;;
        *)
            warn "Distribuição não reconhecida. Tentando com apt..."
            sudo apt update
            sudo apt install -y git curl zsh wget fontconfig unzip
            ;;
    esac
}

# Instalar fontes Nerd Fonts
install_fonts() {
    header "Instalando MesloLGS NF (Nerd Fonts)"
    
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    
    # URLs das fontes MesloLGS NF
    FONTS=(
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )
    
    for font_url in "${FONTS[@]}"; do
        font_name=$(basename "$font_url" | sed 's/%20/ /g')
        if [ ! -f "$FONT_DIR/$font_name" ]; then
            log "Baixando $font_name..."
            wget -q "$font_url" -O "$FONT_DIR/$font_name"
        else
            log "$font_name já existe"
        fi
    done
    
    # Atualizar cache das fontes
    fc-cache -fv >/dev/null 2>&1
    log "Fontes instaladas e cache atualizado"
}

# Instalar Oh My Zsh
install_oh_my_zsh() {
    header "Instalando Oh My Zsh"
    
    if [ -d "$HOME/.oh-my-zsh" ]; then
        warn "Oh My Zsh já está instalado"
        return
    fi
    
    # Instalar sem interromper o script
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log "Oh My Zsh instalado com sucesso"
}

# Instalar Powerlevel10k
install_powerlevel10k() {
    header "Instalando Powerlevel10k"
    
    P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    
    if [ -d "$P10K_DIR" ]; then
        warn "Powerlevel10k já está instalado"
        return
    fi
    
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    log "Powerlevel10k instalado com sucesso"
}

# Instalar plugins do Zsh
install_zsh_plugins() {
    header "Instalando plugins do Zsh"
    
    CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    # zsh-autosuggestions
    if [ ! -d "$CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
        log "Instalando zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$CUSTOM_DIR/plugins/zsh-autosuggestions"
    else
        warn "zsh-autosuggestions já está instalado"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
        log "Instalando zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$CUSTOM_DIR/plugins/zsh-syntax-highlighting"
    else
        warn "zsh-syntax-highlighting já está instalado"
    fi
}

# Configurar .zshrc
configure_zshrc() {
    header "Configurando .zshrc"
    
    # Backup do .zshrc atual se existir
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backup do .zshrc criado"
    fi
    
    # Criar novo .zshrc baseado na configuração atual
    cat > "$HOME/.zshrc" << 'EOF'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration
export PATH="$HOME/.local/bin:$PATH"

# ──────────────────────────────────────────────────────────────────────────────
# Wrapper para sgpt: aceita prompt sem precisar de ASPAS e desliga globbing
# ──────────────────────────────────────────────────────────────────────────────

# Função interna que chama o binário real, juntando tudo em UM só argumento
_sgpt_wrap() {
  # $* -> todos os args unidos por espaço
  command sgpt "$*"
}

# Alias que: 1) desliga globbing, 2) chama o wrap
alias sgpt='noglob _sgpt_wrap'

# Laravel Sail alias
alias sail='[ -f vendor/bin/sail ] && bash vendor/bin/sail'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

    log ".zshrc configurado com suas preferências"
}

# Instalar WezTerm
install_wezterm() {
    header "Instalando WezTerm"
    
    case $DISTRO in
        ubuntu|debian|pop)
            # Adicionar repositório do WezTerm
            curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
            echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
            sudo apt update
            sudo apt install -y wezterm
            ;;
        fedora)
            sudo dnf copr enable wezterm/wezterm-nightly
            sudo dnf install -y wezterm
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm wezterm
            ;;
        *)
            warn "Instalação automática do WezTerm não suportada para $DISTRO"
            log "Visite: https://wezfurlong.org/wezterm/install/linux.html"
            return
            ;;
    esac
    
    log "WezTerm instalado com sucesso"
}

# Configurar WezTerm
configure_wezterm() {
    header "Configurando WezTerm"
    
    mkdir -p "$HOME/.config/wezterm"
    
    cat > "$HOME/.config/wezterm/wezterm.lua" << 'EOF'
local wezterm = require 'wezterm';

return {
  -- Fonte principal e fallback
  font = wezterm.font("MesloLGS NF", { weight = "Regular" }),
  font_size = 12.5,
  line_height = 1.2,

  -- (Opcional) Definição explícita de ligaduras via HarfBuzz
  harfbuzz_features = { "calt=1", "clig=1", "liga=1", "rlig=1" },

  -- Esquema de cores
  color_scheme = "OneDark (base16)",

  -- Transparência suave
  window_background_opacity = 0.90,
  text_background_opacity   = 1.0,

  -- Espaçamento interno
  window_padding = {
    left   = 8,
    right  = 8,
    top    = 6,
    bottom = 6,
  },

  -- Decoração mínima e barra de abas
  window_decorations           = "RESIZE",
  hide_tab_bar_if_only_one_tab = true,
  enable_tab_bar               = true,
  use_fancy_tab_bar            = false,

  -- Cursor
  default_cursor_style = "BlinkingBar",
  cursor_blink_rate    = 800,

  -- Feedback de camp ("bell")
  audible_bell = "Disabled",
  visual_bell = {
    fade_in_duration_ms  = 75,
    fade_in_function     = "EaseIn",
    fade_out_duration_ms = 75,
    fade_out_function    = "EaseOut",
  },

  -- Painéis inativos mais "apagados"
  inactive_pane_hsb = {
    saturation = 0.6,
    brightness = 0.5,
  },

  -- Performance
  max_fps = 144,
  
  -- ⌨️ Atalhos personalizados
  keys = {
    -- SPLITS
    {
      key = "h", mods = "CTRL|ALT",
      action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" },
    },
    {
      key = "v", mods = "CTRL|ALT",
      action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" },
    },

    -- MOVIMENTO ENTRE PAINÉIS
    { key = "LeftArrow", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "RightArrow", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "UpArrow", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "DownArrow", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection("Down") },

    -- FECHAR PAINEL ATUAL
    { key = "W", mods = "CTRL|ALT", action = wezterm.action.CloseCurrentPane { confirm = true } },

    -- NOVA ABA
    { key = "t", mods = "CTRL|ALT", action = wezterm.action.SpawnTab "CurrentPaneDomain" },
    -- FECHAR SPLIT (imitando Super+W)
    { key = "w", mods = "CTRL|ALT", action = wezterm.action.CloseCurrentPane { confirm = true } },

    -- PRÓXIMA/ANTERIOR ABA
    { key = "Tab", mods = "CTRL", action = wezterm.action.ActivateTabRelative(1) },
    { key = "Tab", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },

    -- ZOOM FONTE (equivalente a Ctrl+= e Ctrl+-)
    { key = "+", mods = "CTRL", action = "IncreaseFontSize" },
    { key = "-", mods = "CTRL", action = "DecreaseFontSize" },
    { key = "0", mods = "CTRL", action = "ResetFontSize" },
  },
}
EOF

    log "WezTerm configurado com suas preferências"
}

# Definir Zsh como shell padrão
set_default_shell() {
    header "Configurando Zsh como shell padrão"
    
    if [ "$SHELL" != "$(which zsh)" ]; then
        log "Definindo Zsh como shell padrão..."
        chsh -s $(which zsh)
        log "Shell padrão alterado para Zsh"
    else
        log "Zsh já é o shell padrão"
    fi
}

# Função principal
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
    ╔══════════════════════════════════════════╗
    ║     🚀 INSTALADOR TERMINAL COMPLETO      ║
    ║                                          ║
    ║  • Zsh + Oh My Zsh                      ║
    ║  • Powerlevel10k                        ║
    ║  • Plugins: autosuggestions + syntax    ║
    ║  • WezTerm customizado                  ║
    ║  • Fontes Nerd Fonts                    ║
    ║  • Aliases personalizados               ║
    ╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    read -p "Continuar com a instalação? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Instalação cancelada pelo usuário"
        exit 0
    fi
    
    detect_distro
    log "Distribuição detectada: $DISTRO"
    
    install_dependencies
    install_fonts
    install_oh_my_zsh
    install_powerlevel10k
    install_zsh_plugins
    configure_zshrc
    install_wezterm
    configure_wezterm
    set_default_shell
    
    header "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
    ✅ Tudo instalado e configurado!
    
    📋 PRÓXIMOS PASSOS:
    
    1. Reinicie o terminal ou execute: exec zsh
    2. Na primeira execução, configure o Powerlevel10k
       (será executado automaticamente)
    3. Se usar WezTerm, defina-o como terminal padrão
    
    🎨 ATALHOS DO WEZTERM:
    • Ctrl+Alt+H: Split horizontal
    • Ctrl+Alt+V: Split vertical  
    • Ctrl+Alt+W: Fechar painel
    • Ctrl+Alt+T: Nova aba
    • Ctrl+Tab: Próxima aba
    • Ctrl+Alt+Setas: Navegar entre painéis
    
    🔧 ALIASES DISPONÍVEIS:
    • sgpt: Wrapper para shell-gpt (sem aspas)
    • sail: Laravel Sail
    
    Happy coding! 🚀
EOF
    echo -e "${NC}"
}

# Executar função principal
main "$@"