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

# Clonar el repositorio de configuraciones
echo "[*] Clonando repositorio de configuraciones..."
REPO_URL="https://github.com/itsgabsgarcia/customizer.git"
TEMP_DIR="/tmp/customizer"
git clone "$REPO_URL" "$TEMP_DIR"

# Crear directorios de configuración
mkdir -p "$HOME/.config/tmux"
mkdir -p "$HOME/.config/vim"
mkdir -p "$HOME/.local/bin"

# Copiar configuraciones desde el repositorio clonado
echo "[*] Copiando archivos de configuración..."
if [ -d "$TEMP_DIR" ]; then
    # Copiar configuración de tmux
    if [ -f "$TEMP_DIR/tmux.conf" ]; then
        cp "$TEMP_DIR/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    else
        log_error "TMUX" "Archivo de configuración no encontrado" "tmux.conf no existe en el repositorio"
    fi

    # Copiar configuración de vim
    if [ -f "$TEMP_DIR/vimrc" ]; then
        cp "$TEMP_DIR/vimrc" "$HOME/.config/vim/vimrc"
    else
        log_error "VIM" "Archivo de configuración no encontrado" "vimrc no existe en el repositorio"
    fi

    # Copiar alias
    if [ -f "$TEMP_DIR/bash_aliases" ]; then
        cp "$TEMP_DIR/bash_aliases" "$HOME/.bash_aliases"
    else
        log_error "ALIAS" "Archivo de alias no encontrado" "bash_aliases no existe en el repositorio"
    fi
else
    log_error "REPOSITORIO" "No se pudo clonar el repositorio" "Error al clonar $REPO_URL"
fi

# Crear enlaces simbólicos para los archivos de configuración
ln -sf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$HOME/.config/vim/vimrc" "$HOME/.vimrc"

# Limpiar directorio temporal
rm -rf "$TEMP_DIR"

# Crear scripts de búsqueda con lynx
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

# Verificar paquetes instalados
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

# Verificar archivos de configuración
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

# Verificar servicios críticos
echo -e "\n[*] Verificando servicios críticos:"
SERVICES=("docker")

for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        service_status=$(systemctl status "$service" 2>&1 | head -n 3)
        log_error "SERVICIO" "Servicio $service no está activo" "$service_status"
    fi
done

# Verificar grupos de usuario
echo -e "\n[*] Verificando grupos de usuario:"
if ! groups "$USER" | grep -q "docker"; then
    groups_output=$(groups "$USER")
    log_error "GRUPOS" "Usuario no está en el grupo docker" "Grupos actuales: $groups_output"
fi

# Mostrar reporte final de errores
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

# Recomendaciones finales
if [ ${#ERROR_LOG[@]} -gt 0 ]; then
    echo -e "\n[*] Recomendaciones:"
    echo "1. Para errores de paquetes: sudo apt install -f"
    echo "2. Para errores de servicios: sudo systemctl restart [servicio]"
    echo "3. Para errores de grupos: newgrp docker"
    echo "4. Para errores de configuración: revise los permisos y el contenido de los archivos"
fi

echo -e "\nRecuerda cerrar sesión y volver a entrar para que algunos cambios surtan efecto."