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
GITHUB_REPO="Raspy2DMD"                             # Nom du depot GitHub
GITHUB_BRANCH="main"                                # Branche principale
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}"

# =============================================================================
# CONFIGURATION BOT GITHUB (pour le systeme de feedback)
# Token chiffre avec openssl (AES-256-CBC) - dechiffre uniquement a l'installation
# Le token en clair n'apparait jamais dans le code source
# =============================================================================
# Token chiffre (genere avec: echo -n "TOKEN" | openssl enc -aes-256-cbc -pbkdf2 -a -pass pass:PASSPHRASE)
# Permissions requises: repo, read:org
GH_BOT_TOKEN_ENC="U2FsdGVkX19HeCYaGgA98tJJqfbWoDBjoborTeg9ZowJg+Mc7pStAg9O1UczfLKxjhzzlTsmjr3R7XEQ4ySUHA=="
GH_BOT_PASSPHRASE_PARTS=("raspy" "2dmd" "-feedback" "-bot" "-2024")

# =============================================================================
# CHEMINS D'INSTALLATION
# =============================================================================
INSTALL_DIR="/Raspy2DMD"
MEDIAS_DIR="/Medias"
CONFIG_FILE="${MEDIAS_DIR}/Raspy2DMD.cfg"
# Utiliser la partition principale / au lieu de /tmp (tmpfs en RAM trop petit)
TMP_DIR="/raspy2dmd_install_tmp"
LOG_FILE="/var/log/raspy2dmd_install.log"

# Versions Node.js de fallback (utilisees si la resolution automatique echoue)
# ARMv6 : Node.js 18 LTS (derniere version supportant ARMv6 via unofficial-builds)
NODE_VERSION_ARMv6_FALLBACK="v18.20.5"
# ARMv7 armhf : Node.js 20 LTS (NodeSource ne supporte plus armhf)
NODE_VERSION_ARMv7_FALLBACK="v20.20.0"

# =============================================================================
# CONFIGURATION BASE DE DONNEES
# =============================================================================
# Ces credentials correspondent a ceux de DMDRenderer_Database.py
DB_USER="raspy2dmd"
DB_PASSWORD="raspy2dmd"
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
TOTAL_STEPS=14
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
╔════════════════════════════════════════════════════════════════════════════════════════╗
║                                                                                        ║
║   ██████╗  █████╗ ███████╗██████╗ ██╗   ██╗ ██████╗ ██████╗ ███╗   ███╗██████╗         ║
║   ██╔══██╗██╔══██╗██╔════╝██╔══██╗╚██╗ ██╔╝ ╚════██╗██╔══██╗████╗ ████║██╔══██╗        ║
║   ██████╔╝███████║███████╗██████╔╝ ╚████╔╝   █████╔╝██║  ██║██╔████╔██║██║  ██║        ║
║   ██╔══██╗██╔══██║╚════██║██╔═══╝   ╚██╔╝   ██╔═══╝ ██║  ██║██║╚██╔╝██║██║  ██║        ║
║   ██║  ██║██║  ██║███████║██║        ██║    ███████╗██████╔╝██║ ╚═╝ ██║██████╔╝        ║
║   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝        ╚═╝    ╚══════╝╚═════╝ ╚═╝     ╚═╝╚═════╝         ║
║                                                                                        ║
║                      Installation automatique depuis GitHub                            ║
╚════════════════════════════════════════════════════════════════════════════════════════╝
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

# =============================================================================
# DETECTION DU TYPE DE RASPBERRY PI (ARMv6 vs ARMv7+)
# =============================================================================
# Retourne "armv6" pour Pi Zero/Zero W/Zero WH (BCM2835)
# Retourne "armv7" pour Pi Zero 2 W et autres (BCM2710+)
# IMPORTANT: Ne pas confondre Pi Zero (ARMv6) et Pi Zero 2 (ARMv7)
#
# Revision codes Pi Zero ARMv6:
#   900092 - Pi Zero v1.2
#   900093 - Pi Zero v1.3
#   920092 - Pi Zero v1.2 (Embest)
#   920093 - Pi Zero v1.3 (Embest)
#   9000c1 - Pi Zero W
#
# Revision codes Pi Zero 2 W (ARMv7/ARMv8):
#   902120 - Pi Zero 2 W
# =============================================================================
detect_pi_architecture() {
    # Methode 1: Lire le revision code depuis /proc/cpuinfo
    local revision=$(grep "^Revision" /proc/cpuinfo 2>/dev/null | awk '{print $3}' | tr -d '[:space:]')

    # Liste des revision codes Pi Zero ARMv6
    # Ces codes correspondent aux Pi Zero originaux (pas Pi Zero 2)
    local PI_ZERO_ARMv6_REVISIONS="900092 900093 920092 920093 9000c1"

    if [ -n "$revision" ]; then
        # Verifier si c'est un Pi Zero ARMv6
        for rev in $PI_ZERO_ARMv6_REVISIONS; do
            if [ "$revision" = "$rev" ]; then
                IS_PI_ZERO_ARMv6=true
                echo "armv6"
                return 0
            fi
        done
    fi

    # Methode 2: Verifier l'architecture CPU via uname
    local arch=$(uname -m)
    if [ "$arch" = "armv6l" ]; then
        IS_PI_ZERO_ARMv6=true
        echo "armv6"
        return 0
    fi

    # Par defaut, considerer ARMv7+
    IS_PI_ZERO_ARMv6=false
    echo "armv7"
    return 0
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

    # Detection de l'architecture (ARMv6 vs ARMv7+)
    PI_ARCH=$(detect_pi_architecture)
    if [ "$PI_ARCH" = "armv6" ]; then
        log_info "Architecture ARMv6 detectee (Pi Zero/Zero W/Zero WH)"
        log_warn "Node.js 18 LTS sera installe (Node.js 20+ ne supporte pas ARMv6)"
    else
        log_info "Architecture ARMv7+ detectee"
    fi
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

    # Creation de l'utilisateur raspy2dmd si necessaire
    if ! id "raspy2dmd" &>/dev/null; then
        log_substep "Creation de l'utilisateur raspy2dmd..."
        useradd -m -s /bin/bash raspy2dmd >> "$LOG_FILE" 2>&1
        echo "raspy2dmd:raspy2dmd" | chpasswd >> "$LOG_FILE" 2>&1
        # Ajouter aux groupes necessaires
        usermod -aG sudo,audio,video,gpio,i2c,spi raspy2dmd >> "$LOG_FILE" 2>&1 || true
        log_info "Utilisateur raspy2dmd cree"
    else
        log_info "Utilisateur raspy2dmd existe deja"
    fi

    log_info "Preparation terminee"
}

# =============================================================================
# ETAPE 2 : RECUPERATION DE LA DERNIERE VERSION
# =============================================================================
step_get_version() {
    log_step 2 "Recuperation de la derniere version"

    log_substep "Interrogation de l'API GitHub..."

    # Recuperer la liste des releases et trouver la plus recente par tag
    RELEASES_JSON=$(curl -s "${GITHUB_API_URL}/releases" 2>/dev/null)

    if [ -z "$RELEASES_JSON" ] || echo "$RELEASES_JSON" | grep -q "Not Found"; then
        log_warn "Impossible de recuperer les releases depuis GitHub"
        log_substep "Utilisation de la branche ${GITHUB_BRANCH}..."
        LATEST_VERSION="dev-${GITHUB_BRANCH}"
        USE_BRANCH=true
        return
    fi

    # Extraire le tag de la premiere release de l'application (la plus recente)
    # Pi Zero W/WH (ARMv6) : tag Raspy2DMD_PiZeroWH_vX.X.X.X
    # Autres Pi : tag vX.X.X.X
    if [ "$IS_PI_ZERO_ARMv6" = "true" ]; then
        LATEST_VERSION=$(echo "$RELEASES_JSON" | grep -o '"tag_name": *"[^"]*"' | sed 's/.*: *"\([^"]*\)"/\1/' | grep -E '^Raspy2DMD_PiZeroWH_v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    else
        LATEST_VERSION=$(echo "$RELEASES_JSON" | grep -o '"tag_name": *"[^"]*"' | sed 's/.*: *"\([^"]*\)"/\1/' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    fi

    if [ -z "$LATEST_VERSION" ]; then
        log_warn "Aucune release trouvee"
        log_substep "Utilisation de la branche ${GITHUB_BRANCH}..."
        LATEST_VERSION="dev-${GITHUB_BRANCH}"
        USE_BRANCH=true
        return
    fi

    log_info "Derniere version : $LATEST_VERSION"

    # Recuperer les informations de cette release specifique
    RELEASE_JSON=$(curl -s "${GITHUB_API_URL}/releases/tags/${LATEST_VERSION}" 2>/dev/null)

    # Recuperation de l'URL de telechargement de l'archive .zip
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*: *"\([^"]*\)"/\1/')

    if [ -n "$DOWNLOAD_URL" ]; then
        log_substep "Archive trouvee : $(basename "$DOWNLOAD_URL")"
        USE_BRANCH=false
    else
        log_warn "Aucune archive .zip trouvee dans la release"
        log_substep "Utilisation de la branche ${GITHUB_BRANCH}..."
        USE_BRANCH=true
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
        git curl wget unzip p7zip-full dos2unix
        # Compilation
        build-essential g++ gcc make cython3 gfortran
        # Python - base
        python3 python3-pip python3-dev python3-venv python3-setuptools python3-wheel
        python3-pil python3-pil.imagetk
        # Python - paquets apt pre-compiles (evite la compilation pip longue sur ARM)
        python3-numpy python3-cryptography python3-requests
        # Bibliotheques images
        libfreetype6-dev libjpeg-dev libpng-dev libgif-dev libwebp-dev
        libopenjp2-7-dev zlib1g-dev
        libmagickwand-dev imagemagick
        # Autres bibliotheques
        libffi-dev libssl-dev libxml2-dev libxslt1-dev
        libbz2-dev libreadline-dev libsqlite3-dev
        libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev
        # Mathematiques / calcul scientifique (requis par numpy)
        libopenblas-dev
        # Bluetooth (requis par @abandonware/bleno)
        libbluetooth-dev
        # Bluetooth — agent D-Bus Python (pairing Just Works sans saisie de code)
        python3-dbus python3-gi gir1.2-glib-2.0
        # Audio
        portaudio19-dev libsndfile1 libsndfile1-dev alsa-utils
        # Reseau
        avahi-daemon avahi-utils dnsmasq
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

    # libtiff : libtiff5-dev renomme en libtiff-dev sur Debian 12+ (Bookworm/Trixie)
    if ! dpkg -s libtiff-dev >/dev/null 2>&1 && ! dpkg -s libtiff5-dev >/dev/null 2>&1; then
        apt-get install -y -qq libtiff-dev >> "$LOG_FILE" 2>&1 \
            || apt-get install -y -qq libtiff5-dev >> "$LOG_FILE" 2>&1 \
            || log_warn "libtiff-dev non disponible (TIFF optionnel)"
    fi

    log_info "Dependances systeme installees"

    # Installation des locales (FR, EN, ES, IT, DE) - toutes variantes
    log_substep "Installation des locales (FR, EN, ES, IT, DE)..."

    # S'assurer que locales est installe
    apt-get install -y -qq locales >> "$LOG_FILE" 2>&1 || true

    # Generer les locales necessaires (UTF-8, ISO-8859-1, ISO-8859-15)
    LOCALES=(
        # Francais
        "fr_FR.UTF-8"
        "fr_FR ISO-8859-1"
        "fr_FR.ISO-8859-15 ISO-8859-15"
        "fr_FR@euro ISO-8859-15"
        # Anglais US
        "en_US.UTF-8"
        "en_US ISO-8859-1"
        # Anglais GB
        "en_GB.UTF-8"
        "en_GB ISO-8859-1"
        "en_GB.ISO-8859-15 ISO-8859-15"
        # Espagnol
        "es_ES.UTF-8"
        "es_ES ISO-8859-1"
        "es_ES.ISO-8859-15 ISO-8859-15"
        "es_ES@euro ISO-8859-15"
        # Italien
        "it_IT.UTF-8"
        "it_IT ISO-8859-1"
        "it_IT.ISO-8859-15 ISO-8859-15"
        "it_IT@euro ISO-8859-15"
        # Allemand
        "de_DE.UTF-8"
        "de_DE ISO-8859-1"
        "de_DE.ISO-8859-15 ISO-8859-15"
        "de_DE@euro ISO-8859-15"
    )

    for locale in "${LOCALES[@]}"; do
        # Activer la locale dans /etc/locale.gen (decommenter si commentee)
        locale_pattern=$(echo "$locale" | sed 's/\./\\./g' | sed 's/@/\\@/g')
        sed -i "s/^# *${locale_pattern}/${locale}/" /etc/locale.gen 2>/dev/null || true
    done

    # Regenerer les locales
    locale-gen >> "$LOG_FILE" 2>&1 || true

    # Definir la locale par defaut
    update-locale LANG=fr_FR.UTF-8 >> "$LOG_FILE" 2>&1 || true

    log_info "Locales installees"
}

# =============================================================================
# ETAPE 5 : INSTALLATION DE NODE.JS
# =============================================================================
# Resoudre la derniere version Node.js pour une branche majeure donnee
# Usage: resolve_latest_node_version "20" "https://nodejs.org/dist/latest-v20.x/" "v20.20.0"
# Arg 1: version majeure (pour le pattern de recherche)
# Arg 2: URL du repertoire latest
# Arg 3: version de fallback si la resolution echoue
# Retourne la version resolue (ex: "v20.20.0") via echo
resolve_latest_node_version() {
    local major="$1"
    local url="$2"
    local fallback="$3"

    # Extraire la version depuis le listing du repertoire latest-vXX.x
    local resolved=$(curl -sL --max-time 10 "$url" 2>/dev/null | grep -oP "node-v\K${major}\.[0-9]+\.[0-9]+" | head -1)

    if [ -n "$resolved" ]; then
        echo "v${resolved}"
    else
        echo "$fallback"
    fi
}

step_install_nodejs() {
    log_step 5 "Installation de Node.js"

    # Utiliser la detection d'architecture faite dans check_raspberry_pi()
    # PI_ARCH est defini globalement ("armv6" ou "armv7")
    # IS_PI_ZERO_ARMv6 est un booleen global

    # Verification si Node.js est deja installe avec une version suffisante
    if command -v node &> /dev/null; then
        CURRENT_NODE_VERSION=$(node -v)
        NODE_MAJOR=$(echo $CURRENT_NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
        log_substep "Node.js $CURRENT_NODE_VERSION detecte"

        if [ "$NODE_MAJOR" -ge 18 ]; then
            # Tester que le binaire fonctionne reellement
            # (detecte un binaire ARMv7 installe par erreur sur ARMv6)
            if node -e "process.exit(0)" >> "$LOG_FILE" 2>&1; then
                log_info "Version de Node.js suffisante (>= 18.x) et fonctionnelle"
                return 0
            else
                log_warn "Node.js installe mais ne fonctionne pas (architecture incompatible ?)"
                log_warn "Reinstallation necessaire..."
            fi
        else
            log_warn "Version de Node.js trop ancienne, mise a jour necessaire"
        fi
    fi

    # Utiliser PI_ARCH detecte dans check_raspberry_pi()
    if [ "$PI_ARCH" = "armv6" ]; then
        # Pi Zero, Pi Zero W, Pi Zero WH (ARMv6 - BCM2835)
        # ATTENTION: Pi Zero 2 W est ARMv7/8, pas ARMv6 !
        # NodeSource ne fournit PAS de binaires pour ARMv6 (seulement ARMv7+)
        # Un binaire ARMv7 sur ARMv6 provoque "Illegal instruction"
        # On utilise les builds non-officiels de nodejs.org (Node.js 18 LTS)
        log_warn "Architecture ARMv6 detectee (Pi Zero/Zero W/Zero WH)"
        log_warn "NodeSource ne supporte pas ARMv6 - utilisation des builds non-officiels"

        # Resoudre automatiquement la derniere version 18.x
        NODE_VERSION_ARMv6=$(resolve_latest_node_version "18" "https://unofficial-builds.nodejs.org/download/release/latest-v18.x/" "$NODE_VERSION_ARMv6_FALLBACK")
        log_substep "Installation de Node.js ${NODE_VERSION_ARMv6} (derniere LTS pour ARMv6)..."

        NODE_FILENAME="node-${NODE_VERSION_ARMv6}-linux-armv6l"
        NODE_URL="https://unofficial-builds.nodejs.org/download/release/${NODE_VERSION_ARMv6}/${NODE_FILENAME}.tar.xz"

        # Telecharger
        log_substep "Telechargement de Node.js ${NODE_VERSION_ARMv6} pour ARMv6l..."
        wget -q --show-progress "$NODE_URL" -O "/tmp/${NODE_FILENAME}.tar.xz"

        if [ $? -ne 0 ]; then
            log_error "Echec du telechargement de Node.js pour ARMv6"
            log_error "URL: $NODE_URL"
            log_error "Verifiez la variable NODE_VERSION_ARMv6 (actuellement: $NODE_VERSION_ARMv6)"
            return 1
        fi

        # Supprimer une eventuelle installation NodeSource incompatible
        apt-get remove -y --purge nodejs 2>/dev/null || true
        # Nettoyer le depot NodeSource s'il existe (evite les conflits)
        rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true

        # Extraire et installer dans /usr/local
        log_substep "Extraction et installation..."
        tar -xJf "/tmp/${NODE_FILENAME}.tar.xz" -C /usr/local --strip-components=1 >> "$LOG_FILE" 2>&1
        rm -f "/tmp/${NODE_FILENAME}.tar.xz"

        # Creer les liens symboliques dans /usr/bin (toujours dans le PATH)
        ln -sf /usr/local/bin/node /usr/bin/node 2>/dev/null || true
        ln -sf /usr/local/bin/npm /usr/bin/npm 2>/dev/null || true
        ln -sf /usr/local/bin/npx /usr/bin/npx 2>/dev/null || true

        # Verifier que le binaire fonctionne sur cette architecture
        if node -e "process.exit(0)" >> "$LOG_FILE" 2>&1; then
            log_info "Node.js $(node -v) et npm $(npm -v) installes (build non-officiel ARMv6)"
        else
            log_error "Node.js installe mais ne fonctionne pas sur cette architecture"
            return 1
        fi
    else
        # ARMv7+ (Pi 2, 3, 4, 5, Zero 2 W)
        local DEB_ARCH=$(dpkg --print-architecture 2>/dev/null)

        if [ "$DEB_ARCH" = "arm64" ] || [ "$DEB_ARCH" = "amd64" ]; then
            # OS 64-bit - NodeSource fournit des paquets pour arm64 et amd64
            log_substep "Installation de Node.js 20.x depuis NodeSource..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> "$LOG_FILE" 2>&1
            apt-get install -y -qq nodejs >> "$LOG_FILE" 2>&1

            log_info "Node.js $(node -v) et npm $(npm -v) installes (NodeSource)"
        else
            # OS 32-bit (armhf) - NodeSource ne supporte plus armhf
            # On utilise les builds officiels de nodejs.org (Node.js 20 LTS)
            log_warn "OS 32-bit (${DEB_ARCH}) detecte - NodeSource ne supporte plus cette architecture"

            # Resoudre automatiquement la derniere version 20.x
            NODE_VERSION_ARMv7=$(resolve_latest_node_version "20" "https://nodejs.org/dist/latest-v20.x/" "$NODE_VERSION_ARMv7_FALLBACK")
            log_substep "Installation de Node.js ${NODE_VERSION_ARMv7} depuis nodejs.org..."

            NODE_FILENAME="node-${NODE_VERSION_ARMv7}-linux-armv7l"
            NODE_URL="https://nodejs.org/dist/${NODE_VERSION_ARMv7}/${NODE_FILENAME}.tar.xz"

            # Telecharger
            log_substep "Telechargement de Node.js ${NODE_VERSION_ARMv7} pour armv7l..."
            wget -q --show-progress "$NODE_URL" -O "/tmp/${NODE_FILENAME}.tar.xz"

            if [ $? -ne 0 ]; then
                log_error "Echec du telechargement de Node.js pour armv7l"
                log_error "URL: $NODE_URL"
                log_error "Verifiez la variable NODE_VERSION_ARMv7 (actuellement: $NODE_VERSION_ARMv7)"
                return 1
            fi

            # Supprimer une eventuelle installation NodeSource incompatible
            apt-get remove -y --purge nodejs 2>/dev/null || true
            rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true

            # Extraire et installer dans /usr/local
            log_substep "Extraction et installation..."
            tar -xJf "/tmp/${NODE_FILENAME}.tar.xz" -C /usr/local --strip-components=1 >> "$LOG_FILE" 2>&1
            rm -f "/tmp/${NODE_FILENAME}.tar.xz"

            # Creer les liens symboliques dans /usr/bin
            ln -sf /usr/local/bin/node /usr/bin/node 2>/dev/null || true
            ln -sf /usr/local/bin/npm /usr/bin/npm 2>/dev/null || true
            ln -sf /usr/local/bin/npx /usr/bin/npx 2>/dev/null || true

            # Verifier que le binaire fonctionne
            if node -e "process.exit(0)" >> "$LOG_FILE" 2>&1; then
                log_info "Node.js $(node -v) et npm $(npm -v) installes (build officiel armv7l)"
            else
                log_error "Node.js installe mais ne fonctionne pas sur cette architecture"
                return 1
            fi
        fi
    fi
}

# =============================================================================
# ETAPE 5b : INSTALLATION DE PYTHON 3.10 (Pi Zero W/WH - ARMv6 uniquement)
# PyArmor 9.x ne supporte pas ARMv6, seul PyArmor 7.x est compatible
# PyArmor 7.x ne supporte pas Python 3.11+, d'ou la necessite de Python 3.10
# =============================================================================
step_install_python310() {
    if [ "$IS_PI_ZERO_ARMv6" != "true" ]; then
        return 0
    fi

    log_step "5b" "Installation de Python 3.10 pour Pi Zero WH (ARMv6)"

    # Verifier si deja installe
    if command -v python3.10 &>/dev/null; then
        log_info "Python 3.10 deja installe : $(python3.10 --version)"
        return 0
    fi

    log_warn "Compilation depuis les sources (~1h sur Pi Zero WH)"

    log_substep "Installation des dependances de compilation..."
    apt install -y build-essential zlib1g-dev libncurses5-dev \
        libgdbm-dev libnss3-dev libssl-dev libreadline-dev \
        libffi-dev libsqlite3-dev libbz2-dev liblzma-dev >> "$LOG_FILE" 2>&1

    # Compiler dans /home au lieu de /tmp (/tmp est souvent en tmpfs/RAM,
    # trop petit pour la compilation sur Pi Zero WH avec 512 Mo de RAM)
    local BUILD_DIR="/home/raspy2dmd/build"
    mkdir -p "$BUILD_DIR"

    log_substep "Telechargement des sources Python 3.10.16..."
    cd "$BUILD_DIR"
    wget -q https://www.python.org/ftp/python/3.10.16/Python-3.10.16.tgz
    tar -xzf Python-3.10.16.tgz
    cd Python-3.10.16

    # Sans --enable-optimizations : le PGO compile 3 fois et genere des Go de fichiers .gcda
    # ce qui depasse l'espace disque disponible sur Pi Zero WH (carte SD limitee)
    log_substep "Configuration de Python 3.10..."
    ./configure --with-ensurepip=install --prefix=/usr/local >> "$LOG_FILE" 2>&1

    log_warn "Compilation de Python 3.10 (1 coeur, ~1h sur Pi Zero WH)..."
    make -j1 >> "$LOG_FILE" 2>&1

    log_substep "Installation de Python 3.10 (altinstall)..."
    make altinstall >> "$LOG_FILE" 2>&1

    cd /
    rm -rf "$BUILD_DIR"

    if command -v python3.10 &>/dev/null; then
        log_info "Python $(python3.10 --version) compile et installe"
    else
        log_error "Echec de l'installation de Python 3.10"
        return 1
    fi
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

    # CHEMIN CRITIQUE : make build-python s'execute depuis bindings/python/
    # GCC compile avec -Irgbmatrix/shims (relatif au CWD = bindings/python/)
    # => Imaging.h DOIT etre dans bindings/python/rgbmatrix/shims/
    # Sans ce header, get_image32 n'est pas resolu => ImportError au runtime
    IMAGING_H="bindings/python/rgbmatrix/shims/Imaging.h"
    # Generer un Imaging.h minimal auto-suffisant.
    # Les headers Pillow (src/PIL/ ou src/libImaging/) ont des chaines de dependances
    # complexes et varient selon les versions. Le struct ImagingMemoryInstance est
    # stable depuis Pillow 5.x : seuls les champs jusqu'a image32 sont necessaires.
    log_substep "Creation de Imaging.h minimal pour les bindings Pillow..."
    # Supprimer tout header precedemment telecharge (potentiellement incompatible)
    rm -f "$(dirname "$IMAGING_H")/ImPlatform.h" \
          "$(dirname "$IMAGING_H")/ImagingUtils.h"
    cat > "$IMAGING_H" << 'IMAGING_EOF'
/* Minimal Imaging.h for rpi-rgb-led-matrix
 * Provides just enough of Pillow's C API for get_image32()
 * Struct layout stable across Pillow 6.x - 11.x
 * Auto-generated by Raspy2DMD install script */
#ifndef IMAGING_H
#define IMAGING_H
#include <stdint.h>
typedef uint8_t  UINT8;
typedef int32_t  INT32;
typedef struct ImagingPaletteInstance *ImagingPalette;
typedef struct ImagingMemoryInstance {
    char           mode[6+1];
    int            type;
    int            depth;
    int            bands;
    int            xsize;
    int            ysize;
    ImagingPalette palette;
    UINT8        **image8;
    INT32        **image32;
} *Imaging;
#endif
IMAGING_EOF
    log_info "Imaging.h minimal cree"

    cd bindings/python

    # Sur ARMv6, compiler pour python3.10 (PyArmor 7.x necessite Python <= 3.10)
    if [ "$IS_PI_ZERO_ARMv6" = "true" ] && command -v python3.10 &>/dev/null; then
        log_substep "Compilation pour Python 3.10 (ARMv6)..."
        make build-python PYTHON=$(which python3.10) >> "$LOG_FILE" 2>&1
        make install-python PYTHON=$(which python3.10) >> "$LOG_FILE" 2>&1

        if python3.10 -c "from rgbmatrix import RGBMatrix" 2>/dev/null; then
            log_info "RGB Matrix installe pour Python 3.10"
        else
            log_warn "RGB Matrix : module non importable par Python 3.10"
            log_warn "Cela peut etre normal si vous n'avez pas de matrice LED connectee"
        fi
    else
        make build-python PYTHON=$(which python3) >> "$LOG_FILE" 2>&1
        make install-python PYTHON=$(which python3) >> "$LOG_FILE" 2>&1

        if python3 -c "from rgbmatrix import RGBMatrix" 2>/dev/null; then
            log_info "RGB Matrix installe et fonctionnel"
        else
            log_warn "RGB Matrix installe mais le module n'est pas importable"
            log_warn "Cela peut etre normal si vous n'avez pas de matrice LED connectee"
        fi
    fi
}

# =============================================================================
# ETAPE 7 : INSTALLATION DES DEPENDANCES PYTHON
# =============================================================================
step_install_python_deps() {
    log_step 7 "Installation des dependances Python"

    # Packages a installer via pip
    # Note : numpy, cryptography, requests et Pillow sont deja installes
    # via apt (python3-numpy, python3-cryptography, etc.) a l'etape 4
    # pour eviter la compilation depuis les sources (30-60 min sur ARM 32-bit)
    PYTHON_PACKAGES=(
        "paho-mqtt>=2.0"
        mysql-connector-python
        Wand
        sounddevice
        soundfile
        webcolors
        typing-extensions
    )

    # Determiner la commande pip selon l'architecture
    # Pi Zero W/WH (ARMv6) : python3.10 -m pip (PyArmor 7.x necessite Python <= 3.10)
    # Autres Pi : pip3 (Python systeme)
    if [ "$IS_PI_ZERO_ARMv6" = "true" ] && command -v python3.10 &>/dev/null; then
        PIP_CMD="python3.10 -m pip"
        PYTHON_CHECK_CMD="python3.10"
        log_substep "Utilisation de python3.10 pour les dependances (ARMv6)"
    else
        PIP_CMD="pip3"
        PYTHON_CHECK_CMD="python3"
    fi

    # Verifier les packages deja installes via apt et les ajouter en pip si absents
    # (fallback au cas ou le paquet apt n'etait pas disponible)
    # Format : "nom_pip:nom_import" (le nom d'import Python peut differer du nom pip)
    APT_FALLBACK_PACKAGES=(
        "numpy:numpy"
        "Pillow:PIL"
        "cryptography:cryptography"
        "requests:requests"
    )

    for entry in "${APT_FALLBACK_PACKAGES[@]}"; do
        pkg="${entry%%:*}"
        import_name="${entry##*:}"
        if ! $PYTHON_CHECK_CMD -c "import $import_name" 2>/dev/null; then
            log_warn "$pkg non installe, ajout a la liste pip"
            PYTHON_PACKAGES+=("$pkg")
        fi
    done

    TOTAL=${#PYTHON_PACKAGES[@]}
    CURRENT=0
    FAILED_PACKAGES=()

    for pkg in "${PYTHON_PACKAGES[@]}"; do
        CURRENT=$((CURRENT + 1))
        # Extraire le nom sans version pour l'affichage
        PKG_NAME=$(echo "$pkg" | sed 's/[><=!].*//')
        log_substep "[$CURRENT/$TOTAL] Installation de $PKG_NAME..."

        # Afficher la sortie pip en temps reel avec tee
        # Utiliser PIPESTATUS[0] car "| tee" masque le code retour de pip
        $PIP_CMD install --break-system-packages "$pkg" 2>&1 | tee -a "$LOG_FILE"
        PIP_EXIT=${PIPESTATUS[0]}

        if [ $PIP_EXIT -eq 0 ]; then
            log_info "  $PKG_NAME installe"
        else
            log_warn "  Echec de $PKG_NAME - tentative avec --only-binary..."
            # Retenter sans compilation pour eviter les builds longs sur ARM
            $PIP_CMD install --break-system-packages --only-binary :all: "$pkg" 2>&1 | tee -a "$LOG_FILE"
            PIP_EXIT=${PIPESTATUS[0]}

            if [ $PIP_EXIT -eq 0 ]; then
                log_info "  $PKG_NAME installe (pre-compile)"
            else
                log_warn "  $PKG_NAME : echec de l'installation"
                FAILED_PACKAGES+=("$PKG_NAME")
            fi
        fi
    done

    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        log_warn "Packages Python non installes : ${FAILED_PACKAGES[*]}"
        log_warn "Certaines fonctionnalites pourraient ne pas fonctionner"
    else
        log_info "Toutes les dependances Python installees"
    fi
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
            wget -q --show-progress "$DOWNLOAD_URL" -O raspy2dmd.zip

            log_substep "Extraction de l'archive..."
            mkdir -p "$TMP_DIR/extracted"
            unzip -o raspy2dmd.zip -d "$TMP_DIR/extracted" >> "$LOG_FILE" 2>&1
            rm -f raspy2dmd.zip
            mv "$TMP_DIR/extracted" "$TMP_DIR/extracted_app"
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
        # Verifier si l'archive contient un sous-dossier Raspy2DMD
        if [ -d "$TMP_DIR/extracted_app/Raspy2DMD" ]; then
            # L'archive contient Raspy2DMD/, copier son contenu directement
            cp -r "$TMP_DIR/extracted_app/Raspy2DMD" "$INSTALL_DIR"
        else
            # L'archive contient directement les fichiers
            cp -r "$TMP_DIR/extracted_app" "$INSTALL_DIR"
        fi
    else
        log_error "Fichiers source non trouves"
        exit 1
    fi

    # Conversion des fins de ligne CRLF (Windows) en LF (Unix)
    # Indispensable : les scripts .sh avec CRLF provoquent "$'\r': command not found"
    # Note : rc.local n'a pas d'extension .sh, il faut l'inclure explicitement
    log_substep "Conversion des fins de ligne CRLF -> LF..."
    if command -v dos2unix &>/dev/null; then
        find "$INSTALL_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "rc.local" \) -exec dos2unix -q {} + 2>/dev/null
    else
        # Fallback sans dos2unix : sed
        find "$INSTALL_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "rc.local" \) -exec sed -i 's/\r$//' {} + 2>/dev/null
    fi

    # Permissions
    log_substep "Configuration des permissions..."
    chmod -R 755 "$INSTALL_DIR"

    # Rendre tous les fichiers .sh executables
    log_substep "Rendre les scripts .sh executables..."
    find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} + -print >> "$LOG_FILE" 2>&1

    # Attribuer la propriete a l'utilisateur raspy2dmd
    if id "raspy2dmd" &>/dev/null; then
        chown -R raspy2dmd:raspy2dmd "$INSTALL_DIR"
    fi

    # Supprimer les scripts de mise a jour s'ils sont presents dans l'archive
    # Ces fichiers (SQL, RASPBIAN, RC.LOCAL) sont destines aux mises a jour incrementales
    # et ne doivent pas rester apres une installation fraiche (le script d'installation
    # gere deja la creation des bases de donnees, rc.local, etc.)
    for update_script in "SQL" "RASPBIAN" "RC.LOCAL"; do
        if [ -f "$INSTALL_DIR/scripts/$update_script" ]; then
            rm -f "$INSTALL_DIR/scripts/$update_script"
            log_substep "Script de mise a jour '$update_script' supprime (non necessaire pour une installation fraiche)"
        fi
    done

    log_info "Fichiers installes dans $INSTALL_DIR"
}

# =============================================================================
# ETAPE 9b : COMPILATION DE OMXIV (afficheur d'images GPU)
# =============================================================================
step_install_omxiv() {
    log_step "9b" "Installation de omxiv (afficheur d'images GPU)"

    OMXIV_SRC="${INSTALL_DIR}/omxiv"

    # Verifier que le dossier omxiv existe dans l'installation
    if [ ! -d "$OMXIV_SRC" ]; then
        log_warn "Dossier omxiv non trouve dans ${INSTALL_DIR}"
        log_warn "Etape ignoree - omxiv ne sera pas disponible"
        return 0
    fi

    # Strategie : utiliser le binaire pre-compile si present,
    # sinon tenter la compilation depuis les sources
    if [ -f "$OMXIV_SRC/omxiv.bin" ]; then
        # Binaire pre-compile inclus dans la release
        log_substep "Binaire pre-compile omxiv.bin detecte - installation directe..."
        install -m 755 "$OMXIV_SRC/omxiv.bin" /usr/bin/omxiv

        if [ -f "/usr/bin/omxiv" ]; then
            log_info "omxiv installe depuis le binaire pre-compile"
        else
            log_warn "Echec de la copie de omxiv.bin vers /usr/bin"
        fi
    elif [ -d "/opt/vc" ] && [ -d "/opt/vc/src/hello_pi/libs/ilclient" ]; then
        # Pas de binaire pre-compile mais VideoCore present : compiler depuis les sources
        log_substep "Pas de binaire pre-compile, compilation depuis les sources..."

        cd "$OMXIV_SRC"

        # Nettoyage des anciens fichiers objets (compiles sur une autre machine)
        log_substep "Nettoyage des anciens fichiers objets..."
        rm -f *.o libnsbmp/*.o libnsgif/*.o 2>/dev/null || true
        rm -rf libs/ilclient 2>/dev/null || true

        # Compilation de ilclient
        log_substep "Compilation de la bibliotheque ilclient..."
        mkdir -p libs
        cp -ru /opt/vc/src/hello_pi/libs/ilclient libs/
        make -C libs/ilclient >> "$LOG_FILE" 2>&1

        if [ ! -f "libs/ilclient/libilclient.a" ]; then
            log_warn "Echec de la compilation de ilclient"
            log_warn "omxiv ne sera pas disponible"
            return 0
        fi

        # Compilation de omxiv
        log_substep "Compilation de omxiv (peut prendre quelques minutes)..."
        make clean >> "$LOG_FILE" 2>&1 || true
        make >> "$LOG_FILE" 2>&1

        if [ ! -f "omxiv.bin" ]; then
            log_warn "Echec de la compilation de omxiv"
            log_warn "omxiv ne sera pas disponible"
            return 0
        fi

        # Installation
        log_substep "Installation de omxiv dans /usr/bin/..."
        make install >> "$LOG_FILE" 2>&1

        if [ -f "/usr/bin/omxiv" ]; then
            log_info "omxiv compile et installe avec succes"
        else
            log_warn "Installation de omxiv echouee"
        fi
    else
        log_warn "Pas de binaire pre-compile ni de VideoCore SDK (/opt/vc)"
        log_warn "omxiv ne sera pas disponible"
        return 0
    fi
}

# =============================================================================
# ETAPE 9c : INSTALLATION DES DEPENDANCES NPM
# =============================================================================
step_install_npm_dependencies() {
    log_step "9c" "Installation des dependances npm"

    # Verifier que le dossier web existe
    if [ ! -d "$INSTALL_DIR/web" ]; then
        log_error "Dossier web non trouve dans $INSTALL_DIR"
        return 1
    fi

    # Verifier que package.json existe
    if [ ! -f "$INSTALL_DIR/web/package.json" ]; then
        log_error "Fichier package.json non trouve dans $INSTALL_DIR/web"
        return 1
    fi

    # Supprimer node_modules s'il existe (pour une installation propre)
    if [ -d "$INSTALL_DIR/web/node_modules" ]; then
        log_substep "Suppression des anciens node_modules..."
        rm -rf "$INSTALL_DIR/web/node_modules"
    fi

    # Sur Pi Zero, augmenter le swap AVANT npm install (npm + compilation native = gourmand en RAM)
    if [ "$PI_ARCH" = "armv6" ] && [ -f "/etc/dphys-swapfile" ]; then
        CURRENT_SWAP=$(grep "^CONF_SWAPSIZE=" /etc/dphys-swapfile 2>/dev/null | cut -d= -f2)
        if [ -n "$CURRENT_SWAP" ] && [ "$CURRENT_SWAP" -lt 512 ] 2>/dev/null; then
            log_substep "Augmentation du swap a 512MB pour la compilation npm..."
            sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
            dphys-swapfile setup 2>/dev/null || true
            dphys-swapfile swapon 2>/dev/null || true
        fi
    fi

    # Installer les dependances npm en tant qu'utilisateur raspy2dmd
    log_substep "Installation des packages npm (peut prendre quelques minutes)..."

    # Desactiver set -e temporairement pour gerer les erreurs npm manuellement
    # (sinon le script meurt avant d'atteindre le fallback)
    set +e

    # Executer npm install en tant qu'utilisateur raspy2dmd pour eviter les problemes de permissions
    NPM_SUCCESS=false
    if id "raspy2dmd" &>/dev/null; then
        # Creer le cache npm pour l'utilisateur raspy2dmd
        RASPY_HOME=$(getent passwd raspy2dmd | cut -d: -f6)
        mkdir -p "${RASPY_HOME}/.npm" 2>/dev/null || true
        chown -R raspy2dmd:raspy2dmd "${RASPY_HOME}/.npm" 2>/dev/null || true

        # Tentative 1 : npm ci si package-lock.json existe, sinon npm install
        # Afficher la sortie en temps reel avec tee (comme pour pip)
        if [ -f "$INSTALL_DIR/web/package-lock.json" ]; then
            log_substep "Tentative avec npm ci --omit=dev..."
            sudo -u raspy2dmd bash -c "cd '$INSTALL_DIR/web' && npm ci --omit=dev 2>&1" | tee -a "$LOG_FILE"
            NPM_EXIT=${PIPESTATUS[0]}
        else
            log_substep "Tentative avec npm install --omit=dev..."
            sudo -u raspy2dmd bash -c "cd '$INSTALL_DIR/web' && npm install --omit=dev 2>&1" | tee -a "$LOG_FILE"
            NPM_EXIT=${PIPESTATUS[0]}
        fi

        if [ $NPM_EXIT -eq 0 ]; then
            NPM_SUCCESS=true
        else
            # Tentative 2 : npm install avec --legacy-peer-deps
            log_warn "Erreur lors de l'installation des dependances npm"
            log_warn "Tentative avec npm install --legacy-peer-deps..."
            sudo -u raspy2dmd bash -c "cd '$INSTALL_DIR/web' && npm install --omit=dev --legacy-peer-deps 2>&1" | tee -a "$LOG_FILE"
            NPM_EXIT=${PIPESTATUS[0]}

            if [ $NPM_EXIT -eq 0 ]; then
                NPM_SUCCESS=true
            else
                # Tentative 3 : en tant que root (dernier recours)
                log_warn "Echec en tant que raspy2dmd, tentative en tant que root..."
                cd "$INSTALL_DIR/web"
                npm install --omit=dev --legacy-peer-deps 2>&1 | tee -a "$LOG_FILE"
                NPM_EXIT=${PIPESTATUS[0]}
                cd - > /dev/null
                if [ $NPM_EXIT -eq 0 ]; then
                    NPM_SUCCESS=true
                    # Remettre les permissions
                    chown -R raspy2dmd:raspy2dmd "$INSTALL_DIR/web/node_modules" 2>/dev/null || true
                fi
            fi
        fi
    else
        # Fallback si l'utilisateur raspy2dmd n'existe pas encore
        log_warn "Utilisateur raspy2dmd non trouve, installation en tant que root"
        cd "$INSTALL_DIR/web"
        npm install --omit=dev 2>&1 | tee -a "$LOG_FILE"
        NPM_EXIT=${PIPESTATUS[0]}
        cd - > /dev/null
        [ $NPM_EXIT -eq 0 ] && NPM_SUCCESS=true
    fi

    # Reactiver set -e
    set -e

    if [ "$NPM_SUCCESS" = true ]; then
        log_info "Dependances npm installees avec succes"
    else
        log_error "Installation npm echouee apres toutes les tentatives"
        log_error "Consultez le log : $LOG_FILE"
        log_warn "L'interface web pourrait ne pas fonctionner correctement"
    fi

    log_info "Installation npm terminee"
}

# =============================================================================
# ETAPE 10 : CREATION DE L'ARBORESCENCE MEDIAS
# =============================================================================
step_setup_medias() {
    log_step 10 "Creation de l'arborescence Medias"

    # Configuration pour l'archive Medias
    MEDIAS_TAG="Medias"
    MEDIAS_ARCHIVE_NAME="Medias.7z"
    MEDIAS_DOWNLOADED=false

    # Tentative de telechargement de l'archive Medias depuis la release GitHub
    log_substep "Recherche de l'archive Medias (tag: ${MEDIAS_TAG})..."

    MEDIAS_RELEASE=$(curl -s "${GITHUB_API_URL}/releases/tags/${MEDIAS_TAG}" 2>/dev/null || echo "")

    if [ -n "$MEDIAS_RELEASE" ] && echo "$MEDIAS_RELEASE" | grep -q "tag_name"; then
        # Chercher l'archive Medias.7z dans les assets
        MEDIAS_ARCHIVE_URL=$(echo "$MEDIAS_RELEASE" | grep -o "\"browser_download_url\"[^,]*${MEDIAS_ARCHIVE_NAME}\"" | cut -d'"' -f4 | head -1)

        if [ -n "$MEDIAS_ARCHIVE_URL" ]; then
            log_substep "Archive trouvee : ${MEDIAS_ARCHIVE_NAME}"
            log_substep "Telechargement en cours (cela peut prendre plusieurs minutes)..."

            if wget -q --show-progress "$MEDIAS_ARCHIVE_URL" -O "${TMP_DIR}/medias.7z" 2>/dev/null; then
                log_substep "Extraction de l'archive Medias..."

                # Extraire dans /Medias directement
                mkdir -p "$MEDIAS_DIR"
                7za x -o"${TMP_DIR}/medias_extracted" -y "${TMP_DIR}/medias.7z" >> "$LOG_FILE" 2>&1

                # Copier les fichiers extraits vers /Medias
                if [ -d "${TMP_DIR}/medias_extracted/Medias" ]; then
                    cp -r "${TMP_DIR}/medias_extracted/Medias/"* "$MEDIAS_DIR/" 2>/dev/null || true
                    MEDIAS_DOWNLOADED=true
                    log_info "Fichiers Medias installes depuis l'archive GitHub"
                elif [ -d "${TMP_DIR}/medias_extracted" ]; then
                    cp -r "${TMP_DIR}/medias_extracted/"* "$MEDIAS_DIR/" 2>/dev/null || true
                    MEDIAS_DOWNLOADED=true
                    log_info "Fichiers Medias installes depuis l'archive GitHub"
                fi

                # Nettoyage
                rm -rf "${TMP_DIR}/medias_extracted" "${TMP_DIR}/medias.7z"
            else
                log_warn "Echec du telechargement de l'archive Medias"
            fi
        else
            log_warn "Archive ${MEDIAS_ARCHIVE_NAME} non trouvee dans la release ${MEDIAS_TAG}"
        fi
    else
        log_warn "Release ${MEDIAS_TAG} non trouvee sur GitHub"
    fi

    # Creation/completion de l'arborescence (meme si telechargement reussi, pour s'assurer que tout existe)
    log_substep "Creation/completion de l'arborescence Medias..."

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

    # Creation du fichier de configuration par defaut (seulement s'il n'existe pas)
    if [ ! -f "$CONFIG_FILE" ]; then
        log_substep "Creation du fichier de configuration par defaut..."

        # Determiner pwm_lsb_nanoseconds optimal selon le modele de Pi detecte
        # (memes valeurs que la logique anti-flicker du backend Python)
        if echo "$PI_MODEL" | grep -qi "Zero 2"; then
            PWM_LSB=350
        elif echo "$PI_MODEL" | grep -qi "Zero"; then
            PWM_LSB=400
        elif echo "$PI_MODEL" | grep -qi "Pi 5\|5 Model"; then
            PWM_LSB=200
        elif echo "$PI_MODEL" | grep -qi "Pi 4\|4 Model"; then
            PWM_LSB=250
        elif echo "$PI_MODEL" | grep -qi "Pi 3\|3 Model"; then
            PWM_LSB=300
        else
            PWM_LSB=200
        fi
        log_substep "pwm_lsb_nanoseconds = $PWM_LSB (modele : $PI_MODEL)"

        cat > "$CONFIG_FILE" << CONFIGEOF
[DMDRenderer]
cols = 64
rows = 32
picturewidth = 128
pictureheight = 32
led_chain = 2
vertical_parallel_chain = 1
gpio_slowdown = 4
pwm_lsb_nanoseconds = $PWM_LSB
limit_refresh_rate_hz = 100
pwm_bits = 10
pwm_dither_bits = 0
scan_mode = 0
hardware_mapping = regular
rgb_mode = RGB
brightness = 50
brightnesshours = 50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50
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
default = 1
attract_mode = 0
raspydarts = raspydarts.local
raspydartscanal = raspydarts/dmd
resptoraspydarts = 0
scrollorder = 1,T
checkforupdate = 1
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
enabled = 0
volume = 50
output = local
CONFIGEOF
    fi

    # Permissions
    log_substep "Configuration des permissions du dossier Medias..."
    chmod -R 777 "$MEDIAS_DIR"

    # Attribuer la propriete a l'utilisateur raspy2dmd
    if id "raspy2dmd" &>/dev/null; then
        chown -R raspy2dmd:raspy2dmd "$MEDIAS_DIR"
    fi

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

    log_substep "Configuration de MariaDB..."

    # Verifier si l'utilisateur raspy2dmd peut deja se connecter
    if mysql -u ${DB_USER} -p${DB_PASSWORD} -e "SELECT 1;" &>/dev/null; then
        log_info "Utilisateur ${DB_USER} deja configure"
    else
        log_substep "Creation de l'utilisateur ${DB_USER}..."

        # Creer l'utilisateur raspy2dmd via sudo mysql (unix_socket)
        # Cela fonctionne toujours car root peut se connecter via unix_socket
        sudo mysql << SQLEOF
-- Supprimer l'utilisateur s'il existe (pour repartir proprement)
DROP USER IF EXISTS '${DB_USER}'@'localhost';
DROP USER IF EXISTS '${DB_USER}'@'127.0.0.1';

-- Creer l'utilisateur avec authentification par mot de passe
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';

-- Donner tous les privileges (equivalent a root)
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;

FLUSH PRIVILEGES;
SQLEOF

        # Verification
        if mysql -u ${DB_USER} -p${DB_PASSWORD} -e "SELECT 1;" &>/dev/null; then
            log_info "Utilisateur ${DB_USER} cree avec succes"
        else
            log_error "Impossible de creer l'utilisateur ${DB_USER}"
            log_error "Verifiez que MariaDB est bien demarre"
        fi
    fi

    # Creation des bases de donnees et import des tables
    log_substep "Creation des bases de donnees et des tables..."

    # Script SQL embarque pour la base excluded
    mysql -u ${DB_USER} -p${DB_PASSWORD} << 'SQLEXCLUDED'
CREATE DATABASE IF NOT EXISTS excluded CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE excluded;

CREATE TABLE IF NOT EXISTS `file` (
  `name` varchar(255) DEFAULT NULL,
  `path` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `folder` (
  `name` varchar(255) DEFAULT NULL,
  `path` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `folder` VALUES ('Effets','/Medias/Gifs/Effets');
SQLEXCLUDED

    log_substep "Base excluded creee"

    # Script SQL embarque pour la base effects
    mysql -u ${DB_USER} -p${DB_PASSWORD} << 'SQLEFFECTS'
CREATE DATABASE IF NOT EXISTS effects CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE effects;

CREATE TABLE IF NOT EXISTS `effect` (
  `id` int(20) NOT NULL AUTO_INCREMENT,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `name` varchar(255) NOT NULL DEFAULT '',
  `sound` varchar(255) NOT NULL DEFAULT '',
  `text` varchar(255) NOT NULL DEFAULT '',
  `color` varchar(255) NOT NULL DEFAULT '',
  `sens` varchar(100) NOT NULL DEFAULT '',
  `gif` varchar(255) NOT NULL DEFAULT '',
  `video` varchar(255) NOT NULL DEFAULT '',
  `image` varchar(255) NOT NULL DEFAULT '',
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `effect` (`id`, `active`, `name`, `sound`, `text`, `color`, `sens`, `gif`, `video`, `image`) VALUES
(1,1,'Texte','','Test !','','','','',''),
(2,1,'TexteGif','','PAN !','','','Effets/explosion.gif','',''),
(3,1,'Son','perfect-fart.ogg','','','','','',''),
(4,1,'TexteSon','perfect-fart.ogg','Prout','','','','',''),
(5,1,'TextGifSon','perfect-fart.ogg','Prout','','','Effets/explosion.gif','',''),
(6,1,'Gif','','','','','Effets/explosion.gif','',''),
(7,1,'GifSon','perfect-fart.ogg','','','','Effets/explosion.gif','','');
SQLEFFECTS

    log_substep "Base effects creee"

    # Script SQL embarque pour la base typos
    mysql -u ${DB_USER} -p${DB_PASSWORD} << 'SQLTYPOS'
CREATE DATABASE IF NOT EXISTS typos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE typos;

CREATE TABLE IF NOT EXISTS `font` (
  `id` int(11) DEFAULT NULL,
  `font` char(25) DEFAULT NULL,
  `fontColor` char(15) DEFAULT NULL,
  `fontBackColor` char(15) DEFAULT NULL,
  `pattern` char(25) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `font` (`id`, `font`, `fontColor`, `fontBackColor`, `pattern`) VALUES
(1,'8bit.ttf','255;0;0','0;255;0',''),
(2,'Campfire.ttf','','','OldGame.png');
SQLTYPOS

    log_substep "Base typos creee"
    log_info "Bases de donnees creees avec succes"

    # Verification finale
    if mysql -u ${DB_USER} -p${DB_PASSWORD} -e "SELECT 1;" &>/dev/null; then
        log_info "Connexion MariaDB verifiee avec succes (${DB_USER})"
    else
        log_error "ATTENTION: La connexion MariaDB avec ${DB_USER} ne fonctionne pas"
        log_error "L'application Raspy2DMD ne pourra pas se connecter a la base de donnees"
    fi

    log_info "Base de donnees configuree"
}

# =============================================================================
# ETAPE 12 : CONFIGURATION FINALE
# =============================================================================
step_final_config() {
    log_step 12 "Configuration finale"

    # Note: Les dependances npm sont deja installees a l'etape 9c (step_install_npm_dependencies)

    # Configuration de Mosquitto pour l'acces reseau
    log_substep "Configuration de Mosquitto (MQTT) pour l'acces reseau..."
    mkdir -p /etc/mosquitto/conf.d
    cat > /etc/mosquitto/conf.d/raspy2dmd.conf << 'MQTTEOF'
# Configuration Raspy2DMD - Acces reseau
# Ecoute sur toutes les interfaces reseau (0.0.0.0)
# Accessible via raspy2dmd.local:1883 depuis le reseau local
# Topic principal : raspy2dmd

listener 1883 0.0.0.0
allow_anonymous true
MQTTEOF

    # Demarrage et activation de Mosquitto
    systemctl restart mosquitto 2>/dev/null || true
    systemctl enable mosquitto 2>/dev/null || true
    log_info "Mosquitto configure pour l'acces reseau (port 1883)"

    # Desactiver Bluetooth par defaut (activable via l'interface web Raspy2DMD)
    # Ne force pas si l'utilisateur l'a deja explicitement active
    if ! systemctl is-enabled bluetooth 2>/dev/null | grep -q "^enabled$"; then
        systemctl stop bluetooth 2>/dev/null || true
        systemctl disable bluetooth 2>/dev/null || true
        log_info "Service Bluetooth desactive par defaut (activable via /bluetooth)"
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

        # S'assurer que /etc/rc.local a des fins de ligne LF (pas CRLF)
        # rc.local n'a pas d'extension .sh donc le dos2unix de step_install_files
        # ne le convertit pas automatiquement
        if command -v dos2unix &>/dev/null; then
            dos2unix -q /etc/rc.local 2>/dev/null
        else
            sed -i 's/\r$//' /etc/rc.local 2>/dev/null
        fi

        # Sur Bookworm/Trixie, rc-local.service est genere dynamiquement par
        # systemd-rc-local-generator SANS section [Install], ce qui rend
        # "systemctl enable" inefficace. On cree le fichier de service
        # explicitement pour garantir le demarrage au boot.
        log_substep "Creation du service systemd rc-local.service..."
        if [ ! -f "/etc/systemd/system/rc-local.service" ]; then
            cat > /etc/systemd/system/rc-local.service << 'RCLOCALEOF'
[Unit]
Description=/etc/rc.local Compatibility
ConditionFileIsExecutable=/etc/rc.local
After=network.target mariadb.service mosquitto.service

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutStartSec=0
TimeoutStopSec=10
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
RCLOCALEOF
            log_info "Fichier /etc/systemd/system/rc-local.service cree"
        else
            log_info "rc-local.service existe deja"
        fi

        systemctl daemon-reload 2>/dev/null || true
        systemctl enable rc-local.service 2>/dev/null || true
        log_info "Service rc-local.service active"
    fi

    # Optimisation pour Pi Zero
    # Note: L'augmentation du swap est deja faite a l'etape 9c (step_install_npm_dependencies)
    # avant npm install pour eviter les OOM lors de la compilation native
    if echo "$PI_MODEL" | grep -qi "zero"; then
        log_substep "Application des optimisations pour Pi Zero..."

        # S'assurer que le swap est bien a 512MB (au cas ou l'etape 9c aurait ete sautee)
        if [ -f "/etc/dphys-swapfile" ]; then
            CURRENT_SWAP=$(grep "^CONF_SWAPSIZE=" /etc/dphys-swapfile 2>/dev/null | cut -d= -f2)
            if [ -n "$CURRENT_SWAP" ] && [ "$CURRENT_SWAP" -lt 512 ] 2>/dev/null; then
                sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
                dphys-swapfile setup 2>/dev/null || true
                dphys-swapfile swapon 2>/dev/null || true
            fi
        fi
    fi

    # Configuration du mode USB Gadget (OTG)
    log_substep "Configuration du mode USB Gadget (OTG)..."
    if [ -f "${INSTALL_DIR}/system/usb_gadget_setup.sh" ]; then
        # Rendre les scripts executables
        chmod +x "${INSTALL_DIR}/system/usb_gadget_setup.sh"
        chmod +x "${INSTALL_DIR}/system/usb_gadget_connected.sh" 2>/dev/null || true
        chmod +x "${INSTALL_DIR}/system/usb_gadget_disconnected.sh" 2>/dev/null || true

        # Executer le setup USB Gadget (detecte automatiquement le support OTG)
        # Afficher la sortie pour que l'utilisateur voie les erreurs eventuelles
        bash "${INSTALL_DIR}/system/usb_gadget_setup.sh" 2>&1 | tee -a "$LOG_FILE"
        OTG_EXIT=${PIPESTATUS[0]}

        if [ $OTG_EXIT -eq 0 ]; then
            log_info "Mode USB Gadget configure (sous-reseau 10.0.0.1/24)"
        else
            log_warn "Mode USB Gadget non configure (voir les messages ci-dessus)"
        fi
    else
        log_warn "Script usb_gadget_setup.sh non trouve, mode USB Gadget non configure"
    fi

    # Configuration des partages reseau Samba
    log_substep "Configuration des partages reseau Samba..."
    apt-get install -y -qq samba samba-common >> "$LOG_FILE" 2>&1 || log_warn "Samba non installe"

    # Ajouter les partages a la fin de smb.conf s'ils n'existent pas deja
    if [ -f "/etc/samba/smb.conf" ]; then
        if ! grep -q "\[Medias\]" /etc/samba/smb.conf; then
            cat >> /etc/samba/smb.conf << 'SAMBAEOF'

[Medias]
comment = Dossier principal de Raspy2DMD
path = /Medias
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[EDFJoursTempo]
comment = Dossier des fichiers pour EDFJoursTempo de Raspy2DMD
path = /Medias/EDFJoursTempo
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Fonts]
comment = Dossier des fonts de Raspy2DMD
path = /Medias/Fonts
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Gifs]
comment = Dossier des gifs de Raspy2DMD
path = /Medias/Gifs
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Images]
comment = Dossier des images de Raspy2DMD
path = /Medias/Images
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Jeux]
comment = Dossier des jeux de Raspy2DMD
path = /Medias/Jeux
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Logs]
comment = Dossier des logs de Raspy2DMD
path = /Medias/Logs
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Meteo]
comment = Dossier des fichiers pour la meteo de Raspy2DMD
path = /Medias/Meteo
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Patterns]
comment = Dossier des patterns de Raspy2DMD
path = /Medias/Patterns
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[PerfVisualizer]
comment = Dossier des fichiers pour le perfVisualizer de Raspy2DMD
path = /Medias/PerfVisualizer
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Raspy2DMD]
comment = Dossier des fichiers pour Raspy2DMD
path = /Medias/Raspy2DMD
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Scores]
comment = Dossier des scores pour Raspy2DMD
path = /Medias/Scores
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Sounds]
comment = Dossier des sounds pour Raspy2DMD
path = /Medias/Sounds
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[SpecialsMoves]
comment = Dossier des specialsmoves pour Raspy2DMD
path = /Medias/SpecialsMoves
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Textes]
comment = Dossier des textes pour Raspy2DMD
path = /Medias/Textes
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No

[Videos]
comment = Dossier des videos pour Raspy2DMD
path = /Medias/Videos
writable = yes
valid users = raspy2dmd
force user = raspy2dmd
create mask = 0777
directory mask = 0777
read only = No
SAMBAEOF
            log_info "Partages Samba configures"
        else
            log_info "Partages Samba deja configures"
        fi

        # Forcer l'authentification (pas d'acces invité) dans la section [global]
        grep -q 'map to guest' /etc/samba/smb.conf || sed -i '/^\[global\]/a map to guest = never' /etc/samba/smb.conf
        log_info "Samba : map to guest = never configure"

        # Creer l'utilisateur Samba raspy2dmd (base de mots de passe separee de Linux)
        # printf garantit le \n meme sous dash/sh (contrairement a echo -e)
        printf 'raspy2dmd\nraspy2dmd\n' | smbpasswd -a -s raspy2dmd 2>/dev/null || true
        log_info "Utilisateur Samba raspy2dmd cree (login: raspy2dmd / mdp: raspy2dmd)"

        # Samba configure mais desactive par defaut (l'utilisateur l'active via l'interface web)
        systemctl disable smbd.service 2>/dev/null || true
        systemctl disable nmbd.service 2>/dev/null || true
        systemctl stop smbd.service 2>/dev/null || true
        systemctl stop nmbd.service 2>/dev/null || true
    fi

    # Optimisation affichage LED Matrix : isoler le CPU 3 pour les mises a jour
    log_substep "Configuration de l'optimisation isolcpus pour l'affichage..."
    # Bookworm/Trixie : /boot/firmware/cmdline.txt (prioritaire)
    # Bullseye et avant : /boot/cmdline.txt (fallback)
    if [ -f "/boot/firmware/cmdline.txt" ]; then
        CMDLINE_FILE="/boot/firmware/cmdline.txt"
    else
        CMDLINE_FILE="/boot/cmdline.txt"
    fi

    if [ -f "$CMDLINE_FILE" ]; then
        # Verifier si isolcpus=3 est deja present
        if ! grep -q "isolcpus=3" "$CMDLINE_FILE"; then
            log_substep "Ajout de isolcpus=3 dans $CMDLINE_FILE..."
            # Ajouter isolcpus=3 a la fin de la ligne (cmdline.txt est sur une seule ligne)
            sed -i 's/$/ isolcpus=3/' "$CMDLINE_FILE"
            log_info "isolcpus=3 ajoute - ameliore la fluidite de l'affichage LED"
        else
            log_info "isolcpus=3 deja configure"
        fi

        # Supprimer les interruptions timer sur le coeur isole (reduit le clignotement)
        if ! grep -q "nohz_full=3" "$CMDLINE_FILE"; then
            sed -i 's/$/ nohz_full=3/' "$CMDLINE_FILE"
            log_info "nohz_full=3 ajoute - supprime les ticks timer sur le coeur isole"
        fi

        # Deplacer les callbacks RCU hors du coeur isole
        if ! grep -q "rcu_nocbs=3" "$CMDLINE_FILE"; then
            sed -i 's/$/ rcu_nocbs=3/' "$CMDLINE_FILE"
            log_info "rcu_nocbs=3 ajoute - deplace les callbacks RCU hors du coeur isole"
        fi
    else
        log_warn "Fichier cmdline.txt non trouve, optimisation isolcpus non appliquee"
    fi

    # Passe finale : s'assurer que TOUS les scripts .sh sont executables
    # (certaines etapes precedentes ont pu creer ou modifier des fichiers)
    log_substep "Verification finale des permissions des scripts..."
    find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null
    chmod +x /etc/rc.local 2>/dev/null || true

    log_info "Configuration finale terminee"
}

# =============================================================================
# ETAPE 13 : CONFIGURATION DU BOT GITHUB (pour le feedback)
# =============================================================================
step_setup_github_bot() {
    log_step 13 "Configuration du bot GitHub pour le systeme de feedback"

    # Verifier si gh est installe
    if ! command -v gh &> /dev/null; then
        log_substep "Installation de GitHub CLI (gh)..."
        # Ajouter le depot GitHub CLI
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt-get update -qq >> "$LOG_FILE" 2>&1
        apt-get install -y -qq gh >> "$LOG_FILE" 2>&1

        if ! command -v gh &> /dev/null; then
            log_warn "Impossible d'installer GitHub CLI - le systeme de feedback ne fonctionnera pas"
            return 0
        fi
        log_info "GitHub CLI installe"
    else
        log_info "GitHub CLI deja installe"
    fi

    # Verifier si l'utilisateur raspy2dmd existe
    if ! id "raspy2dmd" &>/dev/null; then
        log_warn "Utilisateur raspy2dmd non trouve - configuration GitHub ignoree"
        return 0
    fi

    # Creer le repertoire .config pour l'utilisateur raspy2dmd (requis par gh)
    RASPY_HOME=$(getent passwd raspy2dmd | cut -d: -f6)
    if [ -n "$RASPY_HOME" ]; then
        mkdir -p "${RASPY_HOME}/.config/gh"
        chown -R raspy2dmd:raspy2dmd "${RASPY_HOME}/.config"
    fi

    # Verifier si gh est deja configure (avec timeout pour eviter blocage)
    if timeout 10 sudo -u raspy2dmd HOME="${RASPY_HOME}" gh auth status &>/dev/null 2>&1; then
        log_info "GitHub CLI deja configure pour l'utilisateur raspy2dmd"
        return 0
    fi

    log_substep "Configuration de l'authentification GitHub..."

    # Reconstruction du passphrase a partir des parties
    GH_PASSPHRASE=""
    for part in "${GH_BOT_PASSPHRASE_PARTS[@]}"; do
        GH_PASSPHRASE="${GH_PASSPHRASE}${part}"
    done

    # Dechiffrement du token dans un fichier temporaire en memoire
    # Utilisation de /dev/shm (tmpfs en RAM) pour ne jamais ecrire sur disque
    GH_TOKEN_TMP="/dev/shm/.gh_token_$$"

    # Dechiffrer le token
    echo "${GH_BOT_TOKEN_ENC}" | openssl enc -aes-256-cbc -pbkdf2 -a -d -pass "pass:${GH_PASSPHRASE}" > "${GH_TOKEN_TMP}" 2>/dev/null

    if [ ! -s "${GH_TOKEN_TMP}" ]; then
        log_warn "Impossible de dechiffrer le token GitHub"
        rm -f "${GH_TOKEN_TMP}" 2>/dev/null
        # Effacer les variables
        unset GH_PASSPHRASE
        return 0
    fi

    # Verifier que le token a ete dechiffre correctement (afficher la taille pour debug)
    TOKEN_SIZE=$(wc -c < "${GH_TOKEN_TMP}" 2>/dev/null | tr -d ' ')
    log "Token dechiffre, taille: ${TOKEN_SIZE} octets"

    # Un token GitHub classique fait environ 40-93 caracteres
    if [ "$TOKEN_SIZE" -lt 30 ] || [ "$TOKEN_SIZE" -gt 200 ]; then
        log_warn "Taille du token suspecte (${TOKEN_SIZE} octets) - token peut-etre invalide"
    fi

    # Configurer gh pour l'utilisateur raspy2dmd
    # IMPORTANT: Utiliser cat et pipe pour passer le token via stdin
    # Capturer stdout et stderr pour diagnostic
    GH_AUTH_RESULT=1
    GH_AUTH_OUTPUT=$(timeout 30 bash -c "cat '${GH_TOKEN_TMP}' | sudo -u raspy2dmd HOME='${RASPY_HOME}' gh auth login --with-token 2>&1")
    GH_AUTH_RESULT=$?

    # Logger la sortie pour diagnostic
    if [ -n "$GH_AUTH_OUTPUT" ]; then
        log "gh auth login output: $GH_AUTH_OUTPUT"
    fi

    # NETTOYAGE IMMEDIAT ET COMPLET
    # 1. Supprimer le fichier temporaire de maniere securisee
    if [ -f "${GH_TOKEN_TMP}" ]; then
        # Ecraser avec des zeros avant de supprimer
        dd if=/dev/zero of="${GH_TOKEN_TMP}" bs=1 count=100 conv=notrunc 2>/dev/null || true
        rm -f "${GH_TOKEN_TMP}"
    fi

    # 2. Effacer les variables sensibles de la memoire
    unset GH_PASSPHRASE
    unset GH_BOT_TOKEN_ENC

    # 3. Vider l'historique bash de la session
    history -c 2>/dev/null || true

    if [ $GH_AUTH_RESULT -eq 0 ]; then
        # Verification (avec timeout)
        if timeout 10 sudo -u raspy2dmd HOME="${RASPY_HOME}" gh auth status &>/dev/null 2>&1; then
            log_info "Bot GitHub configure avec succes"
        else
            log_warn "Configuration GitHub echouee malgre un retour OK"
        fi
    else
        log_warn "Configuration GitHub echouee (code: $GH_AUTH_RESULT)"
        # Afficher l'erreur pour diagnostic (sans le token)
        if [ -n "$GH_AUTH_OUTPUT" ]; then
            log_warn "Erreur: $GH_AUTH_OUTPUT"
        fi
        log_warn "Le systeme de feedback pourrait ne pas fonctionner"
        log_warn "Verifiez le fichier log: $LOG_FILE"
    fi
}

# =============================================================================
# NETTOYAGE
# =============================================================================
cleanup() {
    log_substep "Nettoyage des fichiers temporaires..."
    rm -rf "$TMP_DIR"

    # Nettoyage supplementaire des traces du token GitHub
    rm -f /dev/shm/.gh_token_* 2>/dev/null || true
    unset GH_BOT_TOKEN_ENC 2>/dev/null || true
    unset GH_BOT_PASSPHRASE_PARTS 2>/dev/null || true
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
    echo -e "${BLUE}${BOLD}Acces a l'interface web (par défaut) :${NC}"
    echo -e "  HTTP  : ${GREEN}http://raspy2dmd.local${NC}"
    echo -e "          ${GREEN}http://${IP_ADDRESS}${NC}"
    echo -e "  HTTPS : ${GREEN}https://raspy2dmd.local${NC} (certificat auto-signe)"
    echo ""
    echo -e "${BLUE}${BOLD}Fichiers installes :${NC}"
    echo -e "  Application          : ${INSTALL_DIR}"
    echo -e "  Medias               : ${MEDIAS_DIR}"
    echo -e "  Configuration        : ${CONFIG_FILE}"
    echo -e "  Logs d'installation  : ${LOG_FILE}"
    echo ""
    echo -e "${YELLOW}${BOLD}IMPORTANT :${NC} Un redemarrage est recommande pour finaliser l'installation"
    echo ""

    # Desactiver set -e et le trap ERR pour la section interactive
    # (le vidage du buffer et le read ne doivent pas declencher error_handler)
    set +e
    trap - ERR

    # Vider le buffer du terminal (touches pressees pendant l'installation)
    while read -t 0.1 -n 256 < /dev/tty 2>/dev/null; do :; done

    # Meme pattern que confirm_installation() qui fonctionne sans probleme
    read -p "Voulez-vous redemarrer maintenant ? (o/N) " -n 1 -r < /dev/tty
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

    # Utiliser /dev/tty pour lire l'entree utilisateur meme si le script est pipe
    read -p "Continuer l'installation ? (o/N) " -n 1 -r < /dev/tty
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
    step_install_python310
    step_install_rgbmatrix
    step_install_python_deps
    step_download_raspy2dmd
    step_install_files
    step_install_omxiv
    step_install_npm_dependencies
    step_setup_medias
    step_setup_database
    step_final_config
    step_setup_github_bot

    cleanup
    show_summary
}

# =============================================================================
# LANCEMENT DU SCRIPT
# =============================================================================
main "$@"
