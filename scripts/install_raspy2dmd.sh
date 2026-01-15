#!/bin/bash
##############################################################################
# Raspy2DMD - Script d'installation automatique depuis GitHub
# Version : 2.0.0
# Auteur  : Remi DELCELIER
#
# Ce script installe Raspy2DMD automatiquement sur un Raspberry Pi
# avec Raspberry Pi OS (Debian Bookworm/Trixie)
#
# Usage :
#   curl -sSL https://raw.githubusercontent.com/USERNAME/raspy2dmd/main/scripts/install_raspy2dmd.sh | sudo bash
#
# Ou :
#   wget -qO- https://raw.githubusercontent.com/USERNAME/raspy2dmd/main/scripts/install_raspy2dmd.sh | sudo bash
#
# IMPORTANT: Les fins de ligne doivent etre LF (Unix), pas CRLF (Windows)
##############################################################################

set -e  # Arret en cas d'erreur

# =============================================================================
# CONFIGURATION GITHUB
# =============================================================================
GITHUB_USER="rmdelcelier"                           # Compte GitHub
GITHUB_REPO="raspy2dmd"                             # Nom du depot GitHub
GITHUB_BRANCH="main"                                # Branche principale
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}"

# =============================================================================
# CHEMINS D'INSTALLATION
# =============================================================================
INSTALL_DIR="/Raspy2DMD"
MEDIAS_DIR="/Medias"
CONFIG_FILE="${MEDIAS_DIR}/Raspy2DMD.cfg"
TMP_DIR="/tmp/raspy2dmd_install"
LOG_FILE="/tmp/raspy2dmd_install.log"

# =============================================================================
# CONFIGURATION BASE DE DONNEES
# =============================================================================
DB_USER="root"
DB_PASSWORD="raspberrypi"
DB_HOST="127.0.0.1"

# =============================================================================
# COULEURS POUR L'AFFICHAGE
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# =============================================================================
# VARIABLES GLOBALES
# =============================================================================
TOTAL_STEPS=12
CURRENT_STEP=0
INSTALL_START_TIME=$(date +%s)

# =============================================================================
# FONCTIONS DE LOG ET AFFICHAGE
# =============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log "[INFO] $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log "[WARN] $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "[ERROR] $1"
}

log_step() {
    CURRENT_STEP=$1
    echo ""
    echo -e "${BLUE}${BOLD}[ETAPE $1/$TOTAL_STEPS]${NC} ${CYAN}$2${NC}"
    echo -e "${BLUE}$(printf '%.0s─' {1..60})${NC}"
    log "[STEP $1/$TOTAL_STEPS] $2"
}

log_substep() {
    echo -e "  ${MAGENTA}→${NC} $1"
    log "  → $1"
}

show_progress() {
    local current=$1
    local total=$2
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" $percent
}

# =============================================================================
# BANNIERE
# =============================================================================
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "BANNER"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   ██████╗  █████╗ ███████╗██████╗ ██╗   ██╗██████╗ ██████╗      ║
║   ██╔══██╗██╔══██╗██╔════╝██╔══██╗╚██╗ ██╔╝╚════██╗██╔══██╗     ║
║   ██████╔╝███████║███████╗██████╔╝ ╚████╔╝  █████╔╝██║  ██║     ║
║   ██╔══██╗██╔══██║╚════██║██╔═══╝   ╚██╔╝  ██╔═══╝ ██║  ██║     ║
║   ██║  ██║██║  ██║███████║██║        ██║   ███████╗██████╔╝     ║
║   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝        ╚═╝   ╚══════╝╚═════╝      ║
║                                                                  ║
║              Installation automatique depuis GitHub              ║
║                        Version 2.0.0                             ║
╚══════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
}

# =============================================================================
# VERIFICATION DES PREREQUIS
# =============================================================================
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Ce script doit etre execute en tant que root"
        echo -e "${YELLOW}Utilisez : sudo bash $0${NC}"
        exit 1
    fi
}

check_raspberry_pi() {
    if ! grep -q "Raspberry Pi\|BCM" /proc/cpuinfo 2>/dev/null; then
        log_error "Ce script doit etre execute sur un Raspberry Pi"
        exit 1
    fi

    # Detection du modele
    PI_MODEL=$(cat /proc/cpuinfo | grep "Model" | cut -d':' -f2 | xargs)
    if [ -z "$PI_MODEL" ]; then
        PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi (modele inconnu)")
    fi
    log_info "Materiel detecte : $PI_MODEL"
}

check_os() {
    if ! grep -qE "Debian|Raspbian" /etc/os-release 2>/dev/null; then
        log_error "Ce script necessite Raspberry Pi OS (Debian)"
        exit 1
    fi

    OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    log_info "Systeme d'exploitation : $OS_NAME"
}

check_internet() {
    log_substep "Verification de la connexion Internet..."
    if ! ping -c 1 -W 5 github.com > /dev/null 2>&1; then
        log_error "Pas de connexion Internet. Verifiez votre connexion reseau."
        exit 1
    fi
    log_info "Connexion Internet OK"
}

check_disk_space() {
    log_substep "Verification de l'espace disque..."
    AVAILABLE_SPACE=$(df -m / | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=500  # 500 MB minimum

    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_error "Espace disque insuffisant : ${AVAILABLE_SPACE}MB disponible, ${REQUIRED_SPACE}MB requis"
        exit 1
    fi
    log_info "Espace disque : ${AVAILABLE_SPACE}MB disponible"
}

# =============================================================================
# ETAPE 1 : PREPARATION
# =============================================================================
step_prepare() {
    log_step 1 "Preparation de l'installation"

    check_root
    check_raspberry_pi
    check_os
    check_internet
    check_disk_space

    # Creation du repertoire temporaire
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    # Initialisation du log
    echo "=== Installation Raspy2DMD ===" > "$LOG_FILE"
    echo "Date : $(date)" >> "$LOG_FILE"
    echo "Modele : $PI_MODEL" >> "$LOG_FILE"
    echo "OS : $OS_NAME" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    log_info "Preparation terminee"
}

# =============================================================================
# ETAPE 2 : RECUPERATION DE LA DERNIERE VERSION
# =============================================================================
step_get_version() {
    log_step 2 "Recuperation de la derniere version"

    log_substep "Interrogation de l'API GitHub..."

    LATEST_RELEASE=$(curl -s "${GITHUB_API_URL}/releases/latest")
    LATEST_VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)

    if [ -z "$LATEST_VERSION" ]; then
        log_warn "Impossible de recuperer la version depuis les releases"
        log_substep "Utilisation de la branche ${GITHUB_BRANCH}..."
        LATEST_VERSION="dev-${GITHUB_BRANCH}"
        USE_BRANCH=true
    else
        log_info "Derniere version : $LATEST_VERSION"

        # Recuperation des URLs de telechargement
        DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep "browser_download_url.*\.7z" | cut -d'"' -f4 | head -1)
        MANIFEST_URL=$(echo "$LATEST_RELEASE" | grep "browser_download_url.*manifest.*\.json" | cut -d'"' -f4 | head -1)
        USE_BRANCH=false
    fi
}

# =============================================================================
# ETAPE 3 : MISE A JOUR DU SYSTEME
# =============================================================================
step_update_system() {
    log_step 3 "Mise a jour du systeme"

    log_substep "Mise a jour des paquets (apt update)..."
    apt-get update -qq

    log_substep "Mise a niveau des paquets (apt upgrade)..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

    log_info "Systeme mis a jour"
}

# =============================================================================
# ETAPE 4 : INSTALLATION DES DEPENDANCES SYSTEME
# =============================================================================
step_install_system_deps() {
    log_step 4 "Installation des dependances systeme"

    PACKAGES=(
        # Outils de base
        git curl wget p7zip-full dos2unix
        # Compilation
        build-essential g++ gcc make cython3
        # Python
        python3 python3-pip python3-dev python3-venv python3-setuptools python3-wheel
        python3-pil python3-pil.imagetk
        # Bibliotheques images
        libfreetype6-dev libjpeg-dev libpng-dev libgif-dev libwebp-dev
        libtiff5-dev libopenjp2-7-dev zlib1g-dev
        libmagickwand-dev imagemagick
        # Autres bibliotheques
        libffi-dev libssl-dev libxml2-dev libxslt1-dev
        libbz2-dev libreadline-dev libsqlite3-dev
        libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev
        # Audio
        portaudio19-dev libsndfile1 libsndfile1-dev alsa-utils
        # Reseau
        avahi-daemon avahi-utils
        # MQTT
        mosquitto mosquitto-clients
        # Base de donnees
        mariadb-server mariadb-client
        # Affichage
        fbi
    )

    TOTAL_PACKAGES=${#PACKAGES[@]}
    CURRENT_PKG=0

    for pkg in "${PACKAGES[@]}"; do
        CURRENT_PKG=$((CURRENT_PKG + 1))
        show_progress $CURRENT_PKG $TOTAL_PACKAGES
        apt-get install -y -qq "$pkg" >> "$LOG_FILE" 2>&1 || log_warn "Package $pkg non installe"
    done

    echo ""  # Nouvelle ligne apres la barre de progression
    log_info "Dependances systeme installees"
}

# =============================================================================
# ETAPE 5 : INSTALLATION DE NODE.JS
# =============================================================================
step_install_nodejs() {
    log_step 5 "Installation de Node.js"

    # Verification si Node.js est deja installe avec une version suffisante
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
        log_substep "Node.js $NODE_VERSION detecte"

        if [ "$NODE_MAJOR" -ge 18 ]; then
            log_info "Version de Node.js suffisante (>= 18.x)"
            return 0
        else
            log_warn "Version de Node.js trop ancienne, mise a jour necessaire"
        fi
    fi

    log_substep "Installation de Node.js 20.x depuis NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> "$LOG_FILE" 2>&1
    apt-get install -y -qq nodejs >> "$LOG_FILE" 2>&1

    log_info "Node.js $(node -v) et npm $(npm -v) installes"
}

# =============================================================================
# ETAPE 6 : INSTALLATION DE LA BIBLIOTHEQUE RGB MATRIX
# =============================================================================
step_install_rgbmatrix() {
    log_step 6 "Installation de la bibliotheque RGB Matrix"

    log_warn "Cette etape peut prendre 5-10 minutes sur un Raspberry Pi Zero"

    # Nettoyage d'une eventuelle installation precedente
    if [ -d "/tmp/rpi-rgb-led-matrix" ]; then
        rm -rf /tmp/rpi-rgb-led-matrix
    fi

    log_substep "Clonage du depot rpi-rgb-led-matrix..."
    cd /tmp
    git clone https://github.com/hzeller/rpi-rgb-led-matrix.git >> "$LOG_FILE" 2>&1
    cd rpi-rgb-led-matrix

    log_substep "Compilation de la bibliotheque C++..."
    make -C lib >> "$LOG_FILE" 2>&1

    if [ ! -f "lib/librgbmatrix.a" ]; then
        log_warn "La compilation de la bibliotheque C++ a echoue"
        log_warn "L'application fonctionnera en mode HDMI uniquement"
        return 0
    fi

    log_substep "Installation des bindings Python..."
    cd bindings/python
    make build-python PYTHON=$(which python3) >> "$LOG_FILE" 2>&1
    make install-python PYTHON=$(which python3) >> "$LOG_FILE" 2>&1

    # Test de l'installation
    if python3 -c "from rgbmatrix import RGBMatrix" 2>/dev/null; then
        log_info "RGB Matrix installe et fonctionnel"
    else
        log_warn "RGB Matrix installe mais le module n'est pas importable"
        log_warn "Cela peut etre normal si vous n'avez pas de matrice LED connectee"
    fi
}

# =============================================================================
# ETAPE 7 : INSTALLATION DES DEPENDANCES PYTHON
# =============================================================================
step_install_python_deps() {
    log_step 7 "Installation des dependances Python"

    PYTHON_PACKAGES=(
        numpy
        Pillow
        "paho-mqtt>=2.0"
        mysql-connector-python
        Wand
        requests
        sounddevice
        soundfile
        webcolors
        configparser
        typing-extensions
        cryptography
    )

    log_substep "Installation des packages Python via pip..."
    pip3 install --break-system-packages "${PYTHON_PACKAGES[@]}" >> "$LOG_FILE" 2>&1

    log_info "Dependances Python installees"
}

# =============================================================================
# ETAPE 8 : TELECHARGEMENT DE RASPY2DMD
# =============================================================================
step_download_raspy2dmd() {
    log_step 8 "Telechargement de Raspy2DMD"

    cd "$TMP_DIR"

    if [ "$USE_BRANCH" = true ]; then
        # Telechargement depuis la branche
        log_substep "Telechargement depuis la branche ${GITHUB_BRANCH}..."
        git clone --depth 1 --branch "$GITHUB_BRANCH" "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" raspy2dmd_src >> "$LOG_FILE" 2>&1

        # Deplacer les fichiers
        if [ -d "raspy2dmd_src/Raspy2DMD" ]; then
            mv raspy2dmd_src/Raspy2DMD extracted_app
        else
            mv raspy2dmd_src extracted_app
        fi
    else
        # Telechargement de la release
        log_substep "Telechargement de l'archive (cela peut prendre quelques minutes)..."

        if [ -n "$DOWNLOAD_URL" ]; then
            wget -q --show-progress "$DOWNLOAD_URL" -O raspy2dmd.7z

            log_substep "Extraction de l'archive..."
            7za x -o"$TMP_DIR/extracted" -y raspy2dmd.7z >> "$LOG_FILE" 2>&1
            mv extracted extracted_app
        else
            log_warn "URL de telechargement non trouvee, utilisation de la branche"
            git clone --depth 1 --branch "$GITHUB_BRANCH" "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" raspy2dmd_src >> "$LOG_FILE" 2>&1
            if [ -d "raspy2dmd_src/Raspy2DMD" ]; then
                mv raspy2dmd_src/Raspy2DMD extracted_app
            else
                mv raspy2dmd_src extracted_app
            fi
        fi
    fi

    log_info "Telechargement termine"
}

# =============================================================================
# ETAPE 9 : INSTALLATION DES FICHIERS
# =============================================================================
step_install_files() {
    log_step 9 "Installation des fichiers"

    # Sauvegarde si installation existante
    if [ -d "$INSTALL_DIR" ]; then
        log_substep "Sauvegarde de l'installation existante..."
        BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        mv "$INSTALL_DIR" "$BACKUP_DIR"
        log_info "Sauvegarde creee : $BACKUP_DIR"
    fi

    # Copie des fichiers de l'application
    log_substep "Installation de l'application dans ${INSTALL_DIR}..."

    if [ -d "$TMP_DIR/extracted_app" ]; then
        cp -r "$TMP_DIR/extracted_app" "$INSTALL_DIR"
    else
        log_error "Fichiers source non trouves"
        exit 1
    fi

    # Permissions
    chmod -R 755 "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR"/**/*.sh 2>/dev/null || true

    log_info "Fichiers installes dans $INSTALL_DIR"
}

# =============================================================================
# ETAPE 10 : CREATION DE L'ARBORESCENCE MEDIAS
# =============================================================================
step_setup_medias() {
    log_step 10 "Creation de l'arborescence Medias"

    # Telechargement et execution du script setup_medias.sh
    log_substep "Telechargement du script de creation des medias..."

    SETUP_MEDIAS_URL="${GITHUB_RAW_URL}/scripts/setup_medias.sh"

    if curl -sSL "$SETUP_MEDIAS_URL" -o "$TMP_DIR/setup_medias.sh" 2>/dev/null; then
        chmod +x "$TMP_DIR/setup_medias.sh"
        bash "$TMP_DIR/setup_medias.sh" >> "$LOG_FILE" 2>&1
    else
        log_warn "Script setup_medias.sh non trouve, creation manuelle..."

        # Creation manuelle de l'arborescence
        mkdir -p "$MEDIAS_DIR"/{_Updates,Fonts,Gifs,Videos,Images,Jeux,Logs/Raspy2DMD,Meteo/{DMD,HDMI},Patterns,PerfVisualizer/{DMD,HDMI},Scores,Sounds/Jeux/{FlyBird,Pong,Snake,SpaceWars},SpecialsMoves,Textes,EDFJoursTempo/{DMD,HDMI}}
        mkdir -p "$MEDIAS_DIR"/Raspy2DMD/{gifs_videos/{DMD,HDMI},images/{DMD,HDMI},param_img/{DMD,HDMI},update_gif/{DMD,HDMI},warn/{NoInternet/{DMD,HDMI},NoIP/{DMD,HDMI},RGBTest/{DMD,HDMI}}}

        # Creation des dossiers Scores
        for prefix in D S T; do
            for i in {1..20}; do
                mkdir -p "$MEDIAS_DIR/Scores/${prefix}${i}"
            done
            mkdir -p "$MEDIAS_DIR/Scores/${prefix}B"
        done

        # Creation du fichier de configuration par defaut
        if [ ! -f "$CONFIG_FILE" ]; then
            cat > "$CONFIG_FILE" << 'CONFIGEOF'
[DMDRenderer]
cols = 64
rows = 32
picturewidth = 128
pictureheight = 32
led_chain = 2
vertical_parallel_chain = 1
gpio_slowdown = 4
pwm_lsb_nanoseconds = 130
limit_refresh_rate_hz = 180
pwm_bits = 11
scan_mode = 0
hardware_mapping = regular
rgb_mode = RGB
brightness = 20
brightnesshours = 20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20
led_row_addr_type = 0
center_images = 1
multi_hub = 0
interrupteur = 0

[Directory]
fontsttf = /Medias/Fonts/
gifs = /Medias/Gifs/
videos = /Medias/Videos/
images = /Medias/Images/
scores = /Medias/Scores/
textes = /Medias/Textes/
specialsmoves = /Medias/SpecialsMoves/
meteo = /Medias/Meteo/
patterns = /Medias/Patterns/
sounds = /Medias/Sounds/
perfvisualizer = /Medias/PerfVisualizer
edfjourstempo = /Medias/EDFJoursTempo

[TextRenderer]
defaultfont = Impact.ttf
defaultfontcolor = 0,0,255
pictureverticalmargin = 0
picturebackgroundcolor = 0,0,0
maxfontsize = 30
maxcharacter = 22

[ClockRenderer]
defaultfont_clock = Impact.ttf
defaultfontcolor_clock = 0,0,255
defaultfontcolor_clockshadow = 255,0,0
clockbackgroundimage = OldGame.png
posx_date = 4.0
posy_date = 0.0
sizefont_date = 24
posx_hours = 21.0
posy_hours = 0.0
sizefont_hours = 26
showing_datehours = 2
timeshow_date = 2
timeshow_hours = 4
decal_horaire = 0
format_affichage = fr_FR
format_date = %%d %%b %%Y
format_hours = %%H:%%M:%%S
timezone = Europe/Paris
rpitime =
websynch = 0

[Running]
standalone = 0
default = 0
attract_mode = 0
raspydarts = raspydarts.local
raspydartscanal = raspydarts/dmd
resptoraspydarts = 0
scrollorder = 1,T
checkforupdate = 0
activehdmi = 0

[OpenWeatherMap]
callevery = 15
seeduring = 4
lat = 0.0
lon = 0.0
cityname = Inconnu
zipcode = 0
statecode = 0
countrycode = 0
appid = 0
units = metric
lang = fr
prevision = 1
lastcall = 0001-01-01
lastcallntime = 0001-01-01 00:00
lastcallintime = 0001-01-01 00:00

[Sound]
volume = 50
output = local
CONFIGEOF
        fi
    fi

    # Permissions
    chmod -R 777 "$MEDIAS_DIR"

    log_info "Arborescence Medias creee"
}

# =============================================================================
# ETAPE 11 : CONFIGURATION DE LA BASE DE DONNEES
# =============================================================================
step_setup_database() {
    log_step 11 "Configuration de la base de donnees MariaDB"

    # Demarrage du service
    systemctl start mariadb || true
    systemctl enable mariadb || true

    # Configuration du mot de passe root
    log_substep "Configuration de MariaDB..."

    # Verifier si le mot de passe est deja configure
    if mysql -u root -p${DB_PASSWORD} -e "SELECT 1;" &>/dev/null; then
        log_info "Mot de passe root deja configure"
    else
        # Essayer de configurer le mot de passe
        if mysql -u root -e "SELECT 1;" &>/dev/null; then
            mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; FLUSH PRIVILEGES;" 2>/dev/null || true
        elif sudo mysql -e "SELECT 1;" &>/dev/null; then
            sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; FLUSH PRIVILEGES;" 2>/dev/null || true
        fi
    fi

    # Creation des bases de donnees
    log_substep "Creation des bases de donnees..."

    mysql -u root -p${DB_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS excluded;" 2>/dev/null || true
    mysql -u root -p${DB_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS effects;" 2>/dev/null || true

    # Import des dumps SQL si disponibles
    if [ -f "${INSTALL_DIR}/databases/excluded-dump.sql" ]; then
        log_substep "Import de la base excluded..."
        mysql -u root -p${DB_PASSWORD} excluded < "${INSTALL_DIR}/databases/excluded-dump.sql" 2>/dev/null || true
    fi

    if [ -f "${INSTALL_DIR}/databases/effect-dump.sql" ]; then
        log_substep "Import de la base effects..."
        mysql -u root -p${DB_PASSWORD} effects < "${INSTALL_DIR}/databases/effect-dump.sql" 2>/dev/null || true
    fi

    log_info "Base de donnees configuree"
}

# =============================================================================
# ETAPE 12 : CONFIGURATION FINALE
# =============================================================================
step_final_config() {
    log_step 12 "Configuration finale"

    # Installation des dependances npm pour l'interface web
    if [ -d "${INSTALL_DIR}/web" ]; then
        log_substep "Installation des dependances de l'interface web..."
        cd "${INSTALL_DIR}/web"
        npm install --production >> "$LOG_FILE" 2>&1 || log_warn "npm install a echoue partiellement"
    fi

    # Configuration d'Avahi pour le mDNS
    log_substep "Configuration d'Avahi (mDNS)..."
    cat > /etc/avahi/services/raspy2dmd.service << 'AVAHIEOF'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Raspy2DMD on %h</name>
  <service>
    <type>_http._tcp</type>
    <port>80</port>
  </service>
  <service>
    <type>_https._tcp</type>
    <port>443</port>
  </service>
</service-group>
AVAHIEOF

    systemctl restart avahi-daemon 2>/dev/null || true
    systemctl enable avahi-daemon 2>/dev/null || true

    # Configuration du hostname
    log_substep "Configuration du hostname..."
    CURRENT_HOSTNAME=$(hostname)
    if [ "$CURRENT_HOSTNAME" != "raspy2dmd" ]; then
        hostnamectl set-hostname raspy2dmd 2>/dev/null || true
        sed -i "s/127.0.1.1.*/127.0.1.1\traspy2dmd.local\traspy2dmd/g" /etc/hosts 2>/dev/null || true
    fi

    # Copie du rc.local
    if [ -f "${INSTALL_DIR}/system/rc.local" ]; then
        log_substep "Installation du script de demarrage rc.local..."
        cp /etc/rc.local /etc/rc.local.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        cp "${INSTALL_DIR}/system/rc.local" /etc/rc.local
        chmod +x /etc/rc.local
    fi

    # Optimisation pour Pi Zero
    if echo "$PI_MODEL" | grep -qi "zero"; then
        log_substep "Application des optimisations pour Pi Zero..."

        # Augmentation du swap
        if [ -f "/etc/dphys-swapfile" ]; then
            sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
            dphys-swapfile setup 2>/dev/null || true
            dphys-swapfile swapon 2>/dev/null || true
        fi
    fi

    log_info "Configuration finale terminee"
}

# =============================================================================
# NETTOYAGE
# =============================================================================
cleanup() {
    log_substep "Nettoyage des fichiers temporaires..."
    rm -rf "$TMP_DIR"
}

# =============================================================================
# RESUME FINAL
# =============================================================================
show_summary() {
    INSTALL_END_TIME=$(date +%s)
    INSTALL_DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    INSTALL_MINUTES=$((INSTALL_DURATION / 60))
    INSTALL_SECONDS=$((INSTALL_DURATION % 60))

    # Recuperation de l'adresse IP
    IP_ADDRESS=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}       Installation terminee avec succes !${NC}"
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Duree d'installation :${NC} ${INSTALL_MINUTES}m ${INSTALL_SECONDS}s"
    echo -e "${CYAN}Version installee    :${NC} ${LATEST_VERSION}"
    echo ""
    echo -e "${BLUE}${BOLD}Acces a l'interface web :${NC}"
    echo -e "  HTTP  : ${GREEN}http://raspy2dmd.local${NC}"
    echo -e "          ${GREEN}http://${IP_ADDRESS}${NC}"
    echo -e "  HTTPS : ${GREEN}https://raspy2dmd.local${NC} (certificat auto-signe)"
    echo ""
    echo -e "${BLUE}${BOLD}Fichiers installes :${NC}"
    echo -e "  Application     : ${INSTALL_DIR}"
    echo -e "  Medias          : ${MEDIAS_DIR}"
    echo -e "  Configuration   : ${CONFIG_FILE}"
    echo -e "  Logs            : ${LOG_FILE}"
    echo ""
    echo -e "${BLUE}${BOLD}Commandes utiles :${NC}"
    echo -e "  Demarrer le serveur DMD  : ${YELLOW}sudo bash ${INSTALL_DIR}/ServerRaspy2DMD.sh${NC}"
    echo -e "  Demarrer l'interface web : ${YELLOW}sudo bash ${INSTALL_DIR}/ServerRaspy2DMDWeb.sh${NC}"
    echo -e "  Arreter tous les services: ${YELLOW}sudo bash ${INSTALL_DIR}/StopAllRaspy2DMD.sh${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}IMPORTANT :${NC} Un redemarrage est recommande pour finaliser l'installation"
    echo ""

    read -p "Voulez-vous redemarrer maintenant ? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        log_info "Redemarrage en cours..."
        reboot
    fi
}

# =============================================================================
# GESTION DES ERREURS
# =============================================================================
error_handler() {
    log_error "Une erreur s'est produite a la ligne $1"
    log_error "Consultez le fichier de log : $LOG_FILE"
    cleanup
    exit 1
}

trap 'error_handler $LINENO' ERR
trap 'log_warn "Installation interrompue par l utilisateur" ; cleanup ; exit 1' INT TERM

# =============================================================================
# CONFIRMATION UTILISATEUR
# =============================================================================
confirm_installation() {
    echo ""
    echo -e "${YELLOW}${BOLD}Ce script va :${NC}"
    echo "  - Mettre a jour le systeme"
    echo "  - Installer les dependances systeme (git, python3, nodejs, mariadb, etc.)"
    echo "  - Compiler la bibliotheque RGB Matrix"
    echo "  - Telecharger et installer Raspy2DMD depuis GitHub"
    echo "  - Creer l'arborescence /Medias avec les fichiers necessaires"
    echo "  - Configurer les bases de donnees MariaDB"
    echo "  - Configurer le demarrage automatique"
    echo ""
    echo -e "${CYAN}Temps d'installation estime : 15-45 minutes selon le modele de Pi${NC}"
    echo ""

    read -p "Continuer l'installation ? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        log_warn "Installation annulee par l'utilisateur"
        exit 0
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================
main() {
    show_banner
    confirm_installation

    step_prepare
    step_get_version
    step_update_system
    step_install_system_deps
    step_install_nodejs
    step_install_rgbmatrix
    step_install_python_deps
    step_download_raspy2dmd
    step_install_files
    step_setup_medias
    step_setup_database
    step_final_config

    cleanup
    show_summary
}

# =============================================================================
# LANCEMENT DU SCRIPT
# =============================================================================
main "$@"
