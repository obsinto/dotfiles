# 🚀 Guia Completo do Terminal

> Referência rápida de todos os comandos, atalhos e configurações do seu terminal customizado

---

## 📋 Índice

1. [Atalhos do WezTerm](#-atalhos-do-wezterm)
2. [Aliases Configurados](#-aliases-configurados)
3. [Comandos do Zsh](#-comandos-do-zsh)
4. [Powerlevel10k](#-powerlevel10k)
5. [Plugins](#-plugins)
6. [Customização](#-customização)
7. [Troubleshooting](#-troubleshooting)

---

## ⌨️ Atalhos do WezTerm

### 🪟 Gerenciamento de Painéis (Splits)

| Atalho | Ação |
|--------|------|
| `Ctrl+Alt+H` | Split horizontal (divide janela horizontalmente) |
| `Ctrl+Alt+V` | Split vertical (divide janela verticalmente) |
| `Ctrl+Alt+W` | Fechar painel atual (com confirmação) |
| `Ctrl+Alt+Shift+W` | Fechar painel atual (sem confirmação) |
| `Ctrl+Alt+Z` | Zoom no painel (foco total, esconde os outros) |

### 🧭 Navegação entre Painéis

| Atalho | Ação |
|--------|------|
| `Ctrl+Alt+←` | Ir para o painel da esquerda |
| `Ctrl+Alt+→` | Ir para o painel da direita |
| `Ctrl+Alt+↑` | Ir para o painel de cima |
| `Ctrl+Alt+↓` | Ir para o painel de baixo |

### 📏 Redimensionar Painéis

| Atalho | Ação |
|--------|------|
| `Ctrl+Shift+Alt+←` | Diminuir largura do painel |
| `Ctrl+Shift+Alt+→` | Aumentar largura do painel |
| `Ctrl+Shift+Alt+↑` | Diminuir altura do painel |
| `Ctrl+Shift+Alt+↓` | Aumentar altura do painel |

### 📑 Gerenciamento de Abas

| Atalho | Ação |
|--------|------|
| `Ctrl+Alt+T` | Nova aba |
| `Ctrl+Tab` | Próxima aba |
| `Ctrl+Shift+Tab` | Aba anterior |
| `Ctrl+Shift+1-9` | Ir para aba específica (1 a 9) |

### 🔍 Busca e Navegação

| Atalho | Ação |
|--------|------|
| `Ctrl+Shift+F` | Buscar no terminal |
| `Shift+PgUp` | Rolar para cima |
| `Shift+PgDn` | Rolar para baixo |

### 📝 Copiar e Colar

| Atalho | Ação |
|--------|------|
| `Ctrl+Shift+C` | Copiar texto selecionado |
| `Ctrl+Shift+V` | Colar da área de transferência |
| `Clique direito` | Colar (atalho alternativo) |
| `Duplo clique` | Selecionar palavra |
| `Triplo clique` | Selecionar linha |

### 🔤 Fonte

| Atalho | Ação |
|--------|------|
| `Ctrl++` | Aumentar tamanho da fonte |
| `Ctrl+-` | Diminuir tamanho da fonte |
| `Ctrl+0` | Resetar tamanho da fonte |

---

## 🎯 Aliases Configurados

### Shell GPT (sgpt)

```bash
# Uso normal (SEM aspas necessárias)
sgpt como listar arquivos ocultos no linux

# O alias já adiciona as aspas automaticamente
# Equivalente a: command sgpt "como listar arquivos ocultos no linux"
```

### Laravel Sail

```bash
# Atalho para Laravel Sail
sail up        # Iniciar containers
sail down      # Parar containers
sail artisan   # Executar comandos artisan
sail composer  # Executar composer
sail npm       # Executar npm
sail test      # Rodar testes

# Exemplo de uso completo
sail artisan migrate
sail composer require package/name
sail npm run dev
```

---

## 🐚 Comandos do Zsh

### Navegação de Histórico

| Comando/Atalho | Ação |
|----------------|------|
| `↑` ou `Ctrl+P` | Comando anterior |
| `↓` ou `Ctrl+N` | Próximo comando |
| `Ctrl+R` | Busca reversa no histórico |
| `!!` | Repetir último comando |
| `!$` | Último argumento do comando anterior |
| `!*` | Todos os argumentos do comando anterior |

### Atalhos de Edição

| Atalho | Ação |
|--------|------|
| `Ctrl+A` | Ir para o início da linha |
| `Ctrl+E` | Ir para o fim da linha |
| `Ctrl+U` | Apagar do cursor até o início |
| `Ctrl+K` | Apagar do cursor até o fim |
| `Ctrl+W` | Apagar palavra anterior |
| `Alt+D` | Apagar próxima palavra |
| `Ctrl+L` | Limpar tela |
| `Ctrl+C` | Cancelar comando atual |
| `Ctrl+D` | Sair do shell (EOF) |
| `Ctrl+Z` | Suspender processo atual |

### Expansão e Substituição

```bash
# Expandir diretório
cd ~/Doc[TAB]        # Expande para ~/Documents

# Correção automática
cd Docuemnts         # Sugere: cd Documents

# Glob patterns
ls **/*.js           # Lista todos os .js recursivamente
ls *.{jpg,png}       # Lista todos jpg e png

# Substituição rápida
^antigo^novo         # Substitui 'antigo' por 'novo' no último comando
```

---

## 🎨 Powerlevel10k

### Reconfigurar Prompt

```bash
# Abrir wizard de configuração
p10k configure

# Recarregar configuração
source ~/.zshrc
```

### Segmentos do Prompt

O Powerlevel10k exibe informações contextuais:

- **📁 Diretório atual**: Caminho abreviado
- **🌿 Git**: Branch, status, commits
- **🐍 Python**: Versão do virtualenv
- **📦 Node**: Versão do Node.js
- **🐘 PHP**: Versão do PHP
- **⏱️ Tempo**: Duração do último comando
- **❌ Status**: Código de saída do comando

### Customizar Segmentos

Edite `~/.p10k.zsh`:

```bash
nano ~/.p10k.zsh

# Procure por POWERLEVEL9K_LEFT_PROMPT_ELEMENTS
# e POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS

# Exemplo:
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  dir                   # Diretório
  vcs                   # Git status
  prompt_char          # Caractere do prompt
)

typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status                # Exit code
  command_execution_time # Duração
  background_jobs       # Jobs em background
  time                  # Hora atual
)
```

---

## 🔌 Plugins

### zsh-autosuggestions

**O que faz**: Sugere comandos baseado no histórico

```bash
# Começe a digitar
ls -l[cinza: ls -la ~/Documents]

# Aceitar sugestão
→  (seta direita)

# Aceitar uma palavra
Ctrl+→

# Ignorar sugestão
Continue digitando normalmente
```

**Configurar**:
```bash
# No ~/.zshrc
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"  # Mudar cor da sugestão
ZSH_AUTOSUGGEST_STRATEGY=(history completion)  # Estratégia de sugestão
```

### zsh-syntax-highlighting

**O que faz**: Colore comandos em tempo real

- 🟢 **Verde**: Comando válido
- 🔴 **Vermelho**: Comando inválido
- 🔵 **Azul**: Parâmetro
- 🟡 **Amarelo**: String entre aspas

**Não precisa configurar**, funciona automaticamente!

### git (Oh My Zsh)

**Aliases do Git**:

| Alias | Comando | Descrição |
|-------|---------|-----------|
| `g` | `git` | Git |
| `ga` | `git add` | Adicionar arquivos |
| `gaa` | `git add --all` | Adicionar todos |
| `gc` | `git commit` | Commit |
| `gcm` | `git commit -m` | Commit com mensagem |
| `gst` | `git status` | Status |
| `gp` | `git push` | Push |
| `gl` | `git pull` | Pull |
| `gco` | `git checkout` | Checkout |
| `gcb` | `git checkout -b` | Nova branch |
| `gd` | `git diff` | Diff |
| `glog` | `git log --oneline --decorate --graph` | Log bonito |
| `gsta` | `git stash` | Stash |
| `gstp` | `git stash pop` | Stash pop |

**Ver todos os aliases**:
```bash
alias | grep git
```

---

## 🎨 Customização

### Mudar Tema do WezTerm

Edite `~/.config/wezterm/wezterm.lua`:

```lua
-- Tokyo Night (atual) - Azul/roxo vibrante
colors = {
  foreground = '#c0caf5',
  background = '#1a1b26',
  -- ...
}

-- Ou escolha outro tema pré-definido:
-- Dracula
colors = {
  foreground = '#f8f8f2',
  background = '#282a36',
  -- ...
}

-- Catppuccin Mocha
colors = {
  foreground = '#cdd6f4',
  background = '#1e1e2e',
  -- ...
}

-- Nord
colors = {
  foreground = '#d8dee9',
  background = '#2e3440',
  -- ...
}

-- Gruvbox Dark
colors = {
  foreground = '#ebdbb2',
  background = '#282828',
  -- ...
}
```

### Ajustar Transparência

```lua
-- No wezterm.lua
window_background_opacity = 0.95  -- 0.0 (transparente) a 1.0 (opaco)
```

### Mudar Fonte

```lua
-- No wezterm.lua
font = wezterm.font('FiraCode Nerd Font'),  -- ou outra Nerd Font
font_size = 13.0,  -- Tamanho da fonte
```

**Instalar outras Nerd Fonts**:
```bash
# Baixar de https://www.nerdfonts.com/
# Ou instalar via apt:
sudo apt install fonts-firacode fonts-hack fonts-cascadia-code
```

### Adicionar Aliases Personalizados

Edite `~/.zshrc`:

```bash
nano ~/.zshrc

# Adicione no final do arquivo
alias ll='ls -lah --color=auto'
alias update='sudo apt update && sudo apt upgrade -y'
alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias ps='ps auxf'
alias weather='curl wttr.in'

# Salvar e recarregar
source ~/.zshrc
```

### Criar Funções Personalizadas

```bash
# No ~/.zshrc

# Criar diretório e entrar nele
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extrair qualquer arquivo compactado
extract() {
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)           echo "'$1' não pode ser extraído" ;;
    esac
  else
    echo "'$1' não é um arquivo válido"
  fi
}

# Buscar no histórico
h() {
  history | grep "$1"
}

# Git commit rápido
gc() {
  git add -A && git commit -m "$1" && git push
}
```

---

## 🔧 Troubleshooting

### WezTerm não carrega as cores

```bash
# Verificar qual config está sendo usada
env | grep WEZTERM_CONFIG

# Deve mostrar: WEZTERM_CONFIG_FILE=/home/deyvid/.config/wezterm/wezterm.lua

# Se aparecer ~/.wezterm.lua, remova:
mv ~/.wezterm.lua ~/.wezterm.lua.OLD
```

### Permissões dos plugins do Zsh

```bash
# Corrigir permissões inseguras
compaudit | xargs chmod g-w,o-w

# Ou especificamente:
chmod 755 ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
chmod 755 ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```

### Recarregar configurações

```bash
# Zsh
source ~/.zshrc

# WezTerm (dentro do terminal)
Ctrl+Shift+R

# Ou fechar e abrir novamente
```

### Fontes não aparecem corretamente

```bash
# Atualizar cache de fontes
fc-cache -fv

# Verificar se a fonte está instalada
fc-list | grep -i "MesloLGS"

# Se não aparecer, reinstalar
cd /tmp
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
mkdir -p ~/.local/share/fonts
mv "MesloLGS NF Regular.ttf" ~/.local/share/fonts/
fc-cache -fv
```

### Powerlevel10k não aparece

```bash
# Verificar se está no .zshrc
grep "powerlevel10k" ~/.zshrc

# Deve aparecer: ZSH_THEME="powerlevel10k/powerlevel10k"

# Reconfigurar
p10k configure
```

### Comandos não salvam no histórico

```bash
# Verificar configuração
echo $HISTSIZE
echo $SAVEHIST

# Adicionar no ~/.zshrc se necessário
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
```

### Terminal lento

```bash
# Desabilitar plugins pesados temporariamente
# Edite ~/.zshrc e comente plugins não essenciais

plugins=(
  git
  # zsh-autosuggestions  # Comentar para testar
  # zsh-syntax-highlighting
)

# Recarregar
source ~/.zshrc
```

### Resetar configuração do WezTerm

```bash
# Fazer backup
mv ~/.config/wezterm ~/.config/wezterm.backup

# Recriar pasta
mkdir -p ~/.config/wezterm

# Executar o instalador novamente
./install-terminal-fixed.sh
```

---

## 📚 Recursos Adicionais

### Documentação Oficial

- [WezTerm Docs](https://wezfurlong.org/wezterm/)
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [Zsh Docs](https://zsh.sourceforge.io/Doc/)

### Comunidade

- [r/commandline](https://reddit.com/r/commandline)
- [r/zsh](https://reddit.com/r/zsh)
- [r/unixporn](https://reddit.com/r/unixporn) - Para inspiração visual

### Ferramentas Úteis

```bash
# Ferramentas CLI modernas (instalar separadamente)
sudo apt install -y \
  bat       # Substituto do 'cat' com syntax highlighting
  exa       # Substituto do 'ls' mais bonito
  fd-find   # Substituto do 'find' mais rápido
  ripgrep   # Substituto do 'grep' mais rápido
  fzf       # Fuzzy finder
  tldr      # Man pages simplificadas
  htop      # Monitor de sistema
  ncdu      # Analisador de disco
  lazygit   # Git TUI

# Aliases para as ferramentas
alias cat='bat'
alias ls='exa --icons'
alias find='fd'
alias grep='rg'
```

---

## 🎓 Dicas Pro

### 1. Pesquisa Fuzzy com FZF

```bash
# Instalar FZF
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

# Usar (após instalar)
Ctrl+R  # Buscar no histórico com fuzzy search
Ctrl+T  # Buscar arquivos
Alt+C   # Mudar de diretório
```

### 2. Jump Directories (z ou autojump)

```bash
# Instalar zoxide (melhor que z)
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# Adicionar no ~/.zshrc
eval "$(zoxide init zsh)"

# Usar
z documents    # Pula para ~/Documents (se já visitou)
zi documents   # Modo interativo
```

### 3. Neovim + LazyVim

```bash
# Para edição de código no terminal
# Ver: https://www.lazyvim.org/
```

### 4. tmux para sessões persistentes

```bash
sudo apt install tmux

# Usar junto com WezTerm para sessões que não fecham
tmux new -s trabalho
tmux attach -t trabalho
```

---

**Feito com ❤️ para desenvolvedores que amam o terminal**

> Última atualização: Novembro 2025
