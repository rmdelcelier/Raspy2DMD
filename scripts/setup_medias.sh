#!/bin/bash
##############################################################################
# Raspy2DMD - Script de creation de l'arborescence Medias
# Version : 1.0.0
# Auteur  : Remi DELCELIER
#
# Ce script cree l'arborescence complete du dossier /Medias
# avec tous les sous-dossiers et fichiers necessaires au fonctionnement
# de Raspy2DMD
#
# Usage :
#   sudo bash setup_medias.sh
#
# IMPORTANT: Les fins de ligne doivent etre LF (Unix), pas CRLF (Windows)
##############################################################################

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================
MEDIAS_DIR="/Medias"
CONFIG_FILE="${MEDIAS_DIR}/Raspy2DMD.cfg"
GITHUB_USER="USERNAME"
GITHUB_REPO="raspy2dmd"
GITHUB_BRANCH="main"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# =============================================================================
# COULEURS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# FONCTIONS
# =============================================================================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_substep() {
    echo -e "  ${CYAN}→${NC} $1"
}

# =============================================================================
# VERIFICATION ROOT
# =============================================================================
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit etre execute en tant que root (sudo)"
    exit 1
fi

# =============================================================================
# CREATION DE L'ARBORESCENCE PRINCIPALE
# =============================================================================
log_info "Creation de l'arborescence /Medias..."

# Dossier racine
mkdir -p "$MEDIAS_DIR"

# =============================================================================
# SOUS-DOSSIERS PRINCIPAUX
# =============================================================================
log_substep "Creation des dossiers principaux..."

MAIN_DIRS=(
    "_Updates"
    "Fonts"
    "Gifs"
    "Videos"
    "Images"
    "Jeux"
    "Patterns"
    "Textes"
    "SpecialsMoves"
)

for dir in "${MAIN_DIRS[@]}"; do
    mkdir -p "${MEDIAS_DIR}/${dir}"
done

# =============================================================================
# DOSSIERS AVEC SOUS-STRUCTURES DMD/HDMI
# =============================================================================
log_substep "Creation des dossiers DMD/HDMI..."

DMD_HDMI_DIRS=(
    "Meteo"
    "PerfVisualizer"
    "EDFJoursTempo"
)

for dir in "${DMD_HDMI_DIRS[@]}"; do
    mkdir -p "${MEDIAS_DIR}/${dir}/DMD"
    mkdir -p "${MEDIAS_DIR}/${dir}/HDMI"
done

# =============================================================================
# DOSSIER LOGS
# =============================================================================
log_substep "Creation du dossier Logs..."
mkdir -p "${MEDIAS_DIR}/Logs/Raspy2DMD"

# =============================================================================
# DOSSIER SOUNDS AVEC SOUS-DOSSIERS JEUX
# =============================================================================
log_substep "Creation du dossier Sounds..."
mkdir -p "${MEDIAS_DIR}/Sounds/Jeux/FlyBird"
mkdir -p "${MEDIAS_DIR}/Sounds/Jeux/Pong"
mkdir -p "${MEDIAS_DIR}/Sounds/Jeux/Snake"
mkdir -p "${MEDIAS_DIR}/Sounds/Jeux/SpaceWars"

# =============================================================================
# DOSSIER SCORES (D1-D20, S1-S20, T1-T20, DB, SB, TB)
# =============================================================================
log_substep "Creation des dossiers Scores..."
mkdir -p "${MEDIAS_DIR}/Scores"

for prefix in D S T; do
    for i in {1..20}; do
        mkdir -p "${MEDIAS_DIR}/Scores/${prefix}${i}"
    done
    mkdir -p "${MEDIAS_DIR}/Scores/${prefix}B"
done

# =============================================================================
# DOSSIER RASPY2DMD (FICHIERS SYSTEME)
# =============================================================================
log_substep "Creation du dossier Raspy2DMD (fichiers systeme)..."

# Structure principale
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/gifs_videos/DMD"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/gifs_videos/HDMI"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/images/DMD"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/images/HDMI"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/param_img/DMD"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/param_img/HDMI"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/update_gif/DMD"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/update_gif/HDMI"

# Dossiers warn
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/warn/NoInternet/DMD"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/warn/NoInternet/HDMI"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/warn/NoIP/DMD"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/warn/NoIP/HDMI"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/warn/RGBTest/DMD"
mkdir -p "${MEDIAS_DIR}/Raspy2DMD/warn/RGBTest/HDMI"

# =============================================================================
# DOSSIERS SPECIALSMOVES (MOUVEMENTS SPECIAUX DARTS)
# =============================================================================
log_substep "Creation des dossiers SpecialsMoves..."

SPECIAL_MOVES=(
    "BABY_TON"
    "BAG_O_NUT"
    "BLACK_HAT_THREE_IN_THE_BLACK"
    "BREAKFAST"
    "BUCKET_OF_NAIL"
    "CHAMPAGNE_BREAKFAST"
    "CIRCLE_IT"
    "DEVIL"
    "DINKY_DOO"
    "FEATHERS"
    "GARDEN_GATE_FAT_LADIES"
    "HAPPY_MEAL"
    "HAT_TRICK"
    "HIGH_TON"
    "LOW_TON"
    "MAXIMUM_TON_80"
    "NOT_OLD"
    "ROUND_OF_TERMS"
    "ROUTE_66"
    "STEADY"
    "SUNSET_STRIP"
    "THREE_IN_A_BED"
    "TROMBONES"
    "VARIETIES"
    "WHITE_HORSE"
    "WOODY"
)

for move in "${SPECIAL_MOVES[@]}"; do
    mkdir -p "${MEDIAS_DIR}/SpecialsMoves/${move}"
done

# =============================================================================
# FICHIER DE CONFIGURATION PAR DEFAUT
# =============================================================================
if [ ! -f "$CONFIG_FILE" ]; then
    log_substep "Creation du fichier de configuration par defaut..."
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
    log_info "Fichier de configuration cree"
else
    log_warn "Fichier de configuration existant conserve"
fi

# =============================================================================
# TELECHARGEMENT DES POLICES DE BASE
# =============================================================================
log_substep "Telechargement des polices de base..."

FONTS=(
    "Impact.ttf"
    "8bit.ttf"
)

FONTS_DIR="${MEDIAS_DIR}/Fonts"
for font in "${FONTS[@]}"; do
    if [ ! -f "${FONTS_DIR}/${font}" ]; then
        # Tentative de telechargement depuis GitHub
        FONT_URL="${GITHUB_RAW_URL}/Medias/Fonts/${font}"
        if curl -sSL "$FONT_URL" -o "${FONTS_DIR}/${font}" 2>/dev/null; then
            log_info "Police ${font} telechargee"
        else
            log_warn "Impossible de telecharger ${font}"
        fi
    fi
done

# Si Impact.ttf n'existe toujours pas, copier depuis le systeme
if [ ! -f "${FONTS_DIR}/Impact.ttf" ]; then
    # Chercher Impact.ttf dans les polices systeme
    SYSTEM_IMPACT=$(find /usr/share/fonts -name "Impact*.ttf" 2>/dev/null | head -1)
    if [ -n "$SYSTEM_IMPACT" ]; then
        cp "$SYSTEM_IMPACT" "${FONTS_DIR}/Impact.ttf"
        log_info "Police Impact.ttf copiee depuis le systeme"
    else
        log_warn "Police Impact.ttf non trouvee - vous devrez l'ajouter manuellement"
    fi
fi

# =============================================================================
# TELECHARGEMENT DES IMAGES SYSTEME
# =============================================================================
log_substep "Telechargement des images systeme..."

# Liste des fichiers a telecharger depuis GitHub
SYSTEM_FILES=(
    "Raspy2DMD/gifs_videos/DMD/Raspy2DMD_1.gif"
    "Raspy2DMD/gifs_videos/DMD/Raspy2DMD_2.gif"
    "Raspy2DMD/gifs_videos/HDMI/Raspy2DMD.gif"
    "Raspy2DMD/images/DMD/Raspy2DMD.png"
    "Raspy2DMD/images/HDMI/Raspy2DMD.png"
    "Raspy2DMD/update_gif/DMD/update.gif"
    "Raspy2DMD/update_gif/HDMI/update.gif"
    "Raspy2DMD/warn/NoInternet/DMD/NoInternet.gif"
    "Raspy2DMD/warn/NoInternet/HDMI/NoInternetPart1.gif"
    "Raspy2DMD/warn/NoIP/DMD/NoIp.gif"
    "Raspy2DMD/warn/RGBTest/DMD/rgb_test.png"
    "Raspy2DMD/warn/RGBTest/HDMI/rgb_test.png"
)

DOWNLOADED=0
FAILED=0

for file in "${SYSTEM_FILES[@]}"; do
    FILE_URL="${GITHUB_RAW_URL}/Medias/${file}"
    DEST_FILE="${MEDIAS_DIR}/${file}"
    DEST_DIR=$(dirname "$DEST_FILE")

    mkdir -p "$DEST_DIR"

    if [ ! -f "$DEST_FILE" ]; then
        if curl -sSL "$FILE_URL" -o "$DEST_FILE" 2>/dev/null; then
            DOWNLOADED=$((DOWNLOADED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    fi
done

if [ $DOWNLOADED -gt 0 ]; then
    log_info "${DOWNLOADED} fichiers systeme telecharges"
fi

if [ $FAILED -gt 0 ]; then
    log_warn "${FAILED} fichiers n'ont pas pu etre telecharges"
fi

# =============================================================================
# PERMISSIONS
# =============================================================================
log_substep "Configuration des permissions..."
chmod -R 777 "$MEDIAS_DIR"

# Si l'utilisateur raspy2dmd existe, lui attribuer les fichiers
if id "raspy2dmd" &>/dev/null; then
    chown -R raspy2dmd:raspy2dmd "$MEDIAS_DIR"
fi

# =============================================================================
# RESUME
# =============================================================================
echo ""
log_info "Arborescence Medias creee avec succes !"
echo ""
echo -e "${CYAN}Structure creee :${NC}"
echo "  ${MEDIAS_DIR}/"
echo "  ├── _Updates/           - Stockage des mises a jour"
echo "  ├── Fonts/              - Polices TTF"
echo "  ├── Gifs/               - GIFs animes"
echo "  ├── Videos/             - Fichiers video"
echo "  ├── Images/             - Images statiques"
echo "  ├── Jeux/               - Fichiers des jeux"
echo "  ├── Logs/Raspy2DMD/     - Logs de l'application"
echo "  ├── Meteo/DMD|HDMI/     - Affichage meteo"
echo "  ├── Patterns/           - Motifs de fond"
echo "  ├── PerfVisualizer/     - Visualisation performance"
echo "  ├── Scores/D|S|T 1-20/  - Scores des jeux"
echo "  ├── Sounds/Jeux/        - Sons des jeux"
echo "  ├── SpecialsMoves/      - Mouvements speciaux darts"
echo "  ├── Textes/             - Fichiers texte"
echo "  ├── EDFJoursTempo/      - Jours Tempo EDF"
echo "  ├── Raspy2DMD/          - Fichiers systeme"
echo "  └── Raspy2DMD.cfg       - Configuration"
echo ""
