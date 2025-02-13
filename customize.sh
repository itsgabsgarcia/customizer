#!/bin/bash
# Customize Kali Linux VM Setup Script
# Author: constrainterror
# Description: This script installs and configures additional tools for Kali Linux environment

# Create error log array
declare -a ERROR_LOG

# Function to log errors
log_error() {
    local component=$1
    local message=$2
    local details=$3
    ERROR_LOG+=("[$component] $message | Detalles: $details")
}

# Function to get latest Obsidian release
get_latest_obsidian_release() {
    local latest_release=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d : -f 2,3 | tr -d \")
    echo "$latest_release"
}

# Solicitar credenciales y configuración al inicio
echo "[*] Configuración inicial..."
read -s -p "Introduce la contraseña de sudo: " SUDO_PASS
echo
read -p "Introduce tu nombre para Git: " GIT_NAME
read -p "Introduce tu email para Git: " GIT_EMAIL
echo

# Configure sudo to use password from variable
echo "$SUDO_PASS" | sudo -S echo "Verificando sudo..."

# Update and upgrade the system
echo "[*] Actualizando el sistema..."
echo "$SUDO_PASS" | sudo -S apt update && sudo apt upgrade -y

# Install additional tools (excluyendo las que vienen por defecto en Kali)
echo "[*] Instalando herramientas adicionales..."
echo "$SUDO_PASS" | sudo -S apt install -y \
    kitty \
    lynx \
    cowsay \
    figlet \
    lolcat \
    docker.io \
    docker-compose

# Add the current user to the Docker group
echo "[*] Añadiendo el usuario al grupo Docker..."
echo "$SUDO_PASS" | sudo -S usermod -aG docker $USER

# Install Obsidian
echo "[*] Instalando Obsidian..."
OBSIDIAN_URL=$(get_latest_obsidian_release)
if [ -n "$OBSIDIAN_URL" ]; then
    OBSIDIAN_DEB="/tmp/obsidian.deb"
    wget -O "$OBSIDIAN_DEB" "$OBSIDIAN_URL"
    echo "$SUDO_PASS" | sudo -S dpkg -i "$OBSIDIAN_DEB"
    echo "$SUDO_PASS" | sudo -S apt --fix-broken install -y
    rm -f "$OBSIDIAN_DEB"
else
    log_error "OBSIDIAN" "No se pudo obtener la última versión" "Error en la API de GitHub"
fi

# Configure Git globally
echo "[*] Configurando Git globalmente..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Create configuration directories
mkdir -p "$HOME/.config/tmux"
mkdir -p "$HOME/.config/vim"
mkdir -p "$HOME/.local/bin"

# Copy configuration files
echo "[*] Copiando archivos de configuración..."
cat > "$HOME/.config/tmux/tmux.conf" << 'EOF'
set-option -g history-limit 5000
set-option -g mouse on
set-option -g default-terminal 'screen-256color'
EOF

cat > "$HOME/.config/vim/vimrc" << 'EOF'
syntax on
set number
set tabstop=4
set expandtab
EOF

cat > "$HOME/.bash_aliases" << 'EOF'
# Listing aliases
alias l='ls -lah --group-directories-first'
alias ls='ls --color=auto'

# Search scripts
alias ?='duck'
alias ??='bing'
alias ???='google'

# Editor aliases
alias vi='vim'

# Download alias
alias download='curl -sSLOfk'

# Clipboard alias
alias xc='xclip -selection clipboard'

# Clear terminal
alias c='clear'
EOF

# Create search scripts with lynx
cat << 'INNER' > "$HOME/.local/bin/duck"
#!/bin/bash
search_query=$(echo "$*" | sed 's/ /+/g')
lynx "https://duckduckgo.com/?q=$search_query"
INNER

cat << 'INNER' > "$HOME/.local/bin/bing"
#!/bin/bash
search_query=$(echo "$*" | sed 's/ /+/g')
lynx "https://www.bing.com/search?q=$search_query"
INNER

cat << 'INNER' > "$HOME/.local/bin/google"
#!/bin/bash
search_query=$(echo "$*" | sed 's/ /+/g')
lynx "https://www.google.com/search?q=$search_query"
INNER

chmod +x "$HOME/.local/bin/duck" "$HOME/.local/bin/bing" "$HOME/.local/bin/google"

# Create symbolic links for config files
ln -sf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$HOME/.config/vim/vimrc" "$HOME/.vimrc"

# Check installed packages
echo -e "\n[*] Verificando instalación de paquetes:"
PACKAGES=(
    "kitty"
    "lynx"
    "cowsay"
    "figlet"
    "lolcat"
    "docker.io"
    "docker-compose"
)

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        pkg_status=$(dpkg -l | grep "$pkg" || echo "No encontrado")
        log_error "PAQUETE" "Fallo en la instalación de $pkg" "$pkg_status"
    fi
done

# Check configuration files
echo -e "\n[*] Verificando archivos de configuración:"
CONFIG_FILES=(
    "$HOME/.tmux.conf"
    "$HOME/.vimrc"
    "$HOME/.bash_aliases"
    "$HOME/.local/bin/duck"
    "$HOME/.local/bin/bing"
    "$HOME/.local/bin/google"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        ls_output=$(ls -la "$(dirname "$file")" 2>&1)
        log_error "CONFIG" "Archivo $file no existe" "Contenido del directorio: $ls_output"
    elif [ ! -s "$file" ]; then
        log_error "CONFIG" "Archivo $file está vacío" "$(stat "$file" 2>&1)"
    fi
done

# Check if critical services are running
echo -e "\n[*] Verificando servicios críticos:"
SERVICES=("docker")

for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        service_status=$(systemctl status "$service" 2>&1 | head -n 3)
        log_error "SERVICIO" "Servicio $service no está activo" "$service_status"
    fi
done

# Check user groups
echo -e "\n[*] Verificando grupos de usuario:"
if ! groups "$USER" | grep -q "docker"; then
    groups_output=$(groups "$USER")
    log_error "GRUPOS" "Usuario no está en el grupo docker" "Grupos actuales: $groups_output"
fi

# Display final error report
echo -e "\n[*] Reporte detallado de errores encontrados:"
if [ ${#ERROR_LOG[@]} -eq 0 ]; then
    echo "No se encontraron errores durante la instalación."
else
    echo "Se encontraron ${#ERROR_LOG[@]} errores:"
    for ((i=0; i<${#ERROR_LOG[@]}; i++)); do
        echo -e "\n[$((i+1))] ${ERROR_LOG[$i]}"
    done
    
    echo -e "\nResumen por categorías:"
    echo "Paquetes con errores: $(echo "${ERROR_LOG[@]}" | grep -c "PAQUETE")"
    echo "Errores de configuración: $(echo "${ERROR_LOG[@]}" | grep -c "CONFIG")"
    echo "Errores de servicios: $(echo "${ERROR_LOG[@]}" | grep -c "SERVICIO")"
    echo "Errores de grupos: $(echo "${ERROR_LOG[@]}" | grep -c "GRUPOS")"
fi

# Final recommendations
if [ ${#ERROR_LOG[@]} -gt 0 ]; then
    echo -e "\n[*] Recomendaciones:"
    echo "1. Para errores de paquetes: sudo apt install -f"
    echo "2. Para errores de servicios: sudo systemctl restart [servicio]"
    echo "3. Para errores de grupos: newgrp docker"
    echo "4. Para errores de configuración: revise los permisos y el contenido de los archivos"
fi

echo -e "\nRecuerda cerrar sesión y volver a entrar para que algunos cambios surtan efecto."