#!/bin/bash

# ============================================================================
# 🛠️ INSTALADOR DE FERRAMENTAS DE DESENVOLVIMENTO
# Instalação automática de: Node.js (NVM), Python, CLIs AI (Claude, Codex, Gemini)
# ============================================================================

set -e  # Para em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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

success() {
    echo -e "${MAGENTA}[SUCCESS]${NC} $1"
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

# Instalar dependências básicas
install_dependencies() {
    header "Instalando dependências básicas"
    
    case $DISTRO in
        ubuntu|debian|pop)
            sudo apt update
            sudo apt install -y curl wget git build-essential
            ;;
        fedora)
            sudo dnf install -y curl wget git gcc gcc-c++ make
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm curl wget git base-devel
            ;;
        *)
            warn "Distribuição não reconhecida. Tentando com apt..."
            sudo apt update
            sudo apt install -y curl wget git build-essential
            ;;
    esac
    
    log "Dependências básicas instaladas"
}

# Instalar Python e pip
install_python() {
    header "Configurando Python"
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        log "Python já instalado: v$PYTHON_VERSION"
    else
        log "Instalando Python..."
        case $DISTRO in
            ubuntu|debian|pop)
                sudo apt install -y python3 python3-pip python3-venv
                ;;
            fedora)
                sudo dnf install -y python3 python3-pip
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm python python-pip
                ;;
        esac
        success "Python instalado com sucesso"
    fi
    
    # Verificar pip
    if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
        log "pip já está disponível"
    else
        log "Instalando pip..."
        sudo apt install -y python3-pip
    fi
}

# Instalar NVM (Node Version Manager)
install_nvm() {
    header "Instalando NVM (Node Version Manager)"
    
    if [ -d "$HOME/.nvm" ]; then
        warn "NVM já está instalado"
        return
    fi
    
    # Baixar e instalar NVM
    log "Baixando NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Configurar NVM no shell atual
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    success "NVM instalado com sucesso"
}

# Configurar NVM no .zshrc
configure_nvm_zshrc() {
    header "Configurando NVM no .zshrc"
    
    # Verificar se já está configurado
    if grep -q "NVM_DIR" "$HOME/.zshrc" 2>/dev/null; then
        log "NVM já está configurado no .zshrc"
        return
    fi
    
    # Adicionar configuração do NVM
    cat >> "$HOME/.zshrc" << 'EOF'

# ──────────────────────────────────────────────────────────────────────────────
# NVM - Node Version Manager
# ──────────────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Carrega nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Carrega bash_completion
EOF
    
    log "NVM configurado no .zshrc"
}

# Instalar Node.js via NVM
install_nodejs() {
    header "Instalando Node.js LTS"
    
    # Garantir que NVM está carregado
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if ! command -v nvm &> /dev/null; then
        error "NVM não está disponível. Tente recarregar o shell."
        return 1
    fi
    
    # Instalar Node LTS
    log "Instalando Node.js LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default lts/*
    
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    
    success "Node.js $NODE_VERSION instalado"
    success "npm $NPM_VERSION instalado"
}

# Instalar Shell-GPT (para Claude/GPT)
install_shell_gpt() {
    header "Instalando Shell-GPT"
    
    if command -v sgpt &> /dev/null; then
        warn "Shell-GPT já está instalado"
        return
    fi
    
    log "Instalando shell-gpt via pip..."
    pip install shell-gpt --break-system-packages --upgrade
    
    success "Shell-GPT instalado"
    
    # Instruções de configuração
    echo ""
    warn "⚠️  IMPORTANTE: Configure sua API key do OpenAI:"
    echo "   export OPENAI_API_KEY='sua-chave-aqui'"
    echo "   Ou adicione no ~/.zshrc para persistir"
}

# Instalar Gemini CLI
install_gemini_cli() {
    header "Instalando Gemini CLI"
    
    # Garantir que npm está disponível
    if ! command -v npm &> /dev/null; then
        error "npm não encontrado. Instale Node.js primeiro."
        return 1
    fi
    
    log "Instalando @google/gemini-cli..."
    npm install -g @google/gemini-cli
    
    success "Gemini CLI instalado"
    
    echo ""
    warn "⚠️  IMPORTANTE: Configure sua API key do Google AI:"
    echo "   export GOOGLE_API_KEY='sua-chave-aqui'"
    echo "   Ou adicione no ~/.zshrc para persistir"
}

# Instalar OpenAI Codex
install_codex() {
    header "Instalando OpenAI Codex CLI"
    
    # Garantir que npm está disponível
    if ! command -v npm &> /dev/null; then
        error "npm não encontrado. Instale Node.js primeiro."
        return 1
    fi
    
    log "Instalando @openai/codex..."
    npm install -g @openai/codex
    
    success "Codex CLI instalado"
}

# Instalar Claude CLI (oficial da Anthropic)
install_claude_cli() {
    header "Instalando Claude CLI"
    
    log "Baixando instalador oficial..."
    
    # Verificar se o instalador existe
    if curl -fsSL https://claude.ai/install.sh > /tmp/claude-install.sh 2>/dev/null; then
        bash /tmp/claude-install.sh
        rm /tmp/claude-install.sh
        success "Claude CLI instalado"
        
        echo ""
        warn "⚠️  IMPORTANTE: Autentique com:"
        echo "   claude auth"
    else
        warn "Instalador oficial não disponível. Use shell-gpt com alias 'claude'"
        log "Adicionando alias claude -> sgpt"
        
        if ! grep -q "alias claude='sgpt'" "$HOME/.zshrc" 2>/dev/null; then
            echo "alias claude='sgpt'" >> "$HOME/.zshrc"
        fi
    fi
}

# Configurar MCP (Model Context Protocol) chrome-devtools
configure_mcp_chrome_devtools() {
    header "Configurando MCP chrome-devtools"
    
    echo ""
    echo "O MCP chrome-devtools permite que os CLIs AI interajam com o Chrome DevTools."
    echo ""
    
    # Verificar se os CLIs estão instalados antes de configurar MCP
    local configured_count=0
    
    # Claude MCP
    if command -v claude &> /dev/null; then
        log "Configurando MCP para Claude..."
        claude mcp add chrome-devtools npx chrome-devtools-mcp@latest 2>/dev/null && {
            success "MCP chrome-devtools configurado para Claude"
            ((configured_count++))
        } || warn "Falha ao configurar MCP para Claude (pode já estar configurado)"
    else
        warn "Claude CLI não encontrado, pulando configuração MCP"
    fi
    
    # Codex MCP
    if command -v codex &> /dev/null || npm list -g 2>/dev/null | grep -q codex; then
        log "Configurando MCP para Codex..."
        codex mcp add chrome-devtools -- npx chrome-devtools-mcp@latest 2>/dev/null && {
            success "MCP chrome-devtools configurado para Codex"
            ((configured_count++))
        } || warn "Falha ao configurar MCP para Codex (pode já estar configurado)"
    else
        warn "Codex CLI não encontrado, pulando configuração MCP"
    fi
    
    # Gemini MCP
    if command -v gemini &> /dev/null || npm list -g 2>/dev/null | grep -q gemini-cli; then
        log "Configurando MCP para Gemini..."
        gemini mcp add -s user chrome-devtools npx chrome-devtools-mcp@latest 2>/dev/null && {
            success "MCP chrome-devtools configurado para Gemini"
            ((configured_count++))
        } || warn "Falha ao configurar MCP para Gemini (pode já estar configurado)"
    else
        warn "Gemini CLI não encontrado, pulando configuração MCP"
    fi
    
    if [ $configured_count -gt 0 ]; then
        success "MCP chrome-devtools configurado em $configured_count CLI(s)"
    else
        warn "Nenhum MCP foi configurado. Instale os CLIs primeiro."
    fi
}

# Configurar aliases para CLIs AI
configure_ai_aliases() {
    header "Configurando aliases para CLIs AI"
    
    # Verificar se já existe a seção
    if grep -q "# CLI AI Tools" "$HOME/.zshrc" 2>/dev/null; then
        log "Aliases já configurados no .zshrc"
        return
    fi
    
    cat >> "$HOME/.zshrc" << 'EOF'

# ──────────────────────────────────────────────────────────────────────────────
# CLI AI Tools - Aliases e Configurações
# ──────────────────────────────────────────────────────────────────────────────

# Shell-GPT (pode usar como 'sgpt' ou 'claude')
alias claude='sgpt'

# Codex
alias codex='openai-codex'

# Adicione suas API keys aqui (remova o # para ativar)
# export OPENAI_API_KEY="sk-..."
# export GOOGLE_API_KEY="AIza..."
# export ANTHROPIC_API_KEY="sk-ant-..."

EOF
    
    success "Aliases configurados no .zshrc"
}

# Verificar instalações
verify_installations() {
    header "Verificando instalações"
    
    echo ""
    echo "📦 Verificando ferramentas instaladas:"
    echo ""
    
    # Python
    if command -v python3 &> /dev/null; then
        echo "  ✅ Python: $(python3 --version)"
    else
        echo "  ❌ Python: Não instalado"
    fi
    
    # pip
    if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
        echo "  ✅ pip: Instalado"
    else
        echo "  ❌ pip: Não instalado"
    fi
    
    # NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if command -v nvm &> /dev/null; then
        echo "  ✅ NVM: Instalado"
    else
        echo "  ❌ NVM: Não instalado"
    fi
    
    # Node.js
    if command -v node &> /dev/null; then
        echo "  ✅ Node.js: $(node --version)"
    else
        echo "  ❌ Node.js: Não instalado"
    fi
    
    # npm
    if command -v npm &> /dev/null; then
        echo "  ✅ npm: $(npm --version)"
    else
        echo "  ❌ npm: Não instalado"
    fi
    
    # Shell-GPT
    if command -v sgpt &> /dev/null; then
        echo "  ✅ Shell-GPT: Instalado"
    else
        echo "  ❌ Shell-GPT: Não instalado"
    fi
    
    # Gemini CLI
    if command -v gemini &> /dev/null || npm list -g 2>/dev/null | grep -q gemini-cli; then
        echo "  ✅ Gemini CLI: Instalado"
    else
        echo "  ❌ Gemini CLI: Não instalado"
    fi
    
    # Codex
    if command -v codex &> /dev/null || npm list -g 2>/dev/null | grep -q codex; then
        echo "  ✅ Codex CLI: Instalado"
    else
        echo "  ❌ Codex CLI: Não instalado"
    fi
    
    echo ""
}

# Função principal
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
    ╔══════════════════════════════════════════╗
    ║   🛠️  INSTALADOR DE DEV TOOLS & AI CLI  ║
    ║                                          ║
    ║  • Node.js via NVM                      ║
    ║  • Python + pip                         ║
    ║  • Shell-GPT (Claude/GPT)               ║
    ║  • Gemini CLI                           ║
    ║  • OpenAI Codex                         ║
    ║  • Claude CLI (Anthropic)               ║
    ║  • MCP chrome-devtools                  ║
    ╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    echo "Este script irá instalar ferramentas de desenvolvimento e CLIs AI."
    echo "Você poderá escolher quais ferramentas instalar."
    echo ""
    read -p "Continuar com a instalação? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Instalação cancelada pelo usuário"
        exit 0
    fi
    
    detect_distro
    log "Distribuição detectada: $DISTRO"
    
    # Menu de seleção
    echo ""
    echo "Selecione o que deseja instalar:"
    echo ""
    read -p "  Instalar Node.js (NVM)? (Y/n): " install_node
    read -p "  Instalar Python/pip? (Y/n): " install_py
    read -p "  Instalar Shell-GPT? (Y/n): " install_sgpt
    read -p "  Instalar Gemini CLI? (Y/n): " install_gem
    read -p "  Instalar Codex CLI? (Y/n): " install_cod
    read -p "  Instalar Claude CLI? (Y/n): " install_clau
    read -p "  Configurar MCP chrome-devtools? (Y/n): " install_mcp
    
    echo ""
    install_dependencies
    
    # Python
    if [[ ! $install_py =~ ^[Nn]$ ]]; then
        install_python
    fi
    
    # Node.js via NVM
    if [[ ! $install_node =~ ^[Nn]$ ]]; then
        install_nvm
        configure_nvm_zshrc
        
        # Recarregar para ter acesso ao nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        install_nodejs
    fi
    
    # Shell-GPT
    if [[ ! $install_sgpt =~ ^[Nn]$ ]]; then
        install_shell_gpt
    fi
    
    # Gemini CLI
    if [[ ! $install_gem =~ ^[Nn]$ ]]; then
        install_gemini_cli
    fi
    
    # Codex CLI
    if [[ ! $install_cod =~ ^[Nn]$ ]]; then
        install_codex
    fi
    
    # Claude CLI
    if [[ ! $install_clau =~ ^[Nn]$ ]]; then
        install_claude_cli
    fi
    
    # Configurar aliases
    configure_ai_aliases
    
    # Configurar MCP chrome-devtools
    if [[ ! $install_mcp =~ ^[Nn]$ ]]; then
        configure_mcp_chrome_devtools
    fi
    
    # Verificar instalações
    verify_installations
    
    header "🎉 INSTALAÇÃO CONCLUÍDA!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
    ✅ Ferramentas instaladas com sucesso!
    
    📋 PRÓXIMOS PASSOS:
    
    1. Recarregue o shell:
       exec zsh
       
       Ou feche e abra o terminal
    
    2. Configure suas API keys no ~/.zshrc:
       
       # OpenAI (para Shell-GPT e Codex)
       export OPENAI_API_KEY="sk-..."
       
       # Google AI (para Gemini)
       export GOOGLE_API_KEY="AIza..."
       
       # Anthropic (para Claude CLI)
       export ANTHROPIC_API_KEY="sk-ant-..."
    
    3. Teste os comandos:
       node --version
       npm --version
       sgpt "olá mundo"
       claude "teste"
       gemini "teste"
       codex "teste"
    
    4. MCP chrome-devtools (se configurado):
       Os CLIs agora podem interagir com Chrome DevTools
       para debugging e inspeção de páginas web!
    
    💡 DICAS:
    • Use 'nvm install <version>' para instalar outras versões do Node
    • Use 'nvm use <version>' para trocar entre versões
    • Aliases configurados: claude -> sgpt
    • MCP permite que os CLIs AI acessem ferramentas do browser
    
    📚 DOCUMENTAÇÃO:
    • Shell-GPT: https://github.com/TheR1D/shell_gpt
    • NVM: https://github.com/nvm-sh/nvm
    • Gemini: https://ai.google.dev/
    • Claude: https://docs.anthropic.com/
    • MCP: https://modelcontextprotocol.io/
    
    Happy coding! 🚀
EOF
    echo -e "${NC}"
    
    echo ""
    warn "IMPORTANTE: Recarregue o shell para aplicar as mudanças:"
    echo "  exec zsh"
}

# Executar função principal
main "$@"
