#!/bin/bash
##############################################################################
# Raspy2DMD - Script de creation de l'arborescence Medias
# Version : 2.0.0
# Auteur  : Remi DELCELIER
#
# Ce script telecharge et installe les fichiers Medias depuis les releases
# GitHub, puis complete l'arborescence avec les dossiers necessaires.
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
TMP_DIR="/tmp/raspy2dmd_medias"

# Configuration GitHub
GITHUB_USER="rmdelcelier"
GITHUB_REPO="raspy2dmd"
GITHUB_BRANCH="main"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Configuration de l'archive Medias
MEDIAS_TAG="Raspy2DMD_Medias"
MEDIAS_ARCHIVE_NAME="Medias.7z"

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
# NETTOYAGE DU DOSSIER TEMPORAIRE
# =============================================================================
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# =============================================================================
# TENTATIVE DE TELECHARGEMENT DE L'ARCHIVE MEDIAS DEPUIS GITHUB RELEASES
# =============================================================================
log_info "Recherche de l'archive Medias (tag: ${MEDIAS_TAG})..."

MEDIAS_ARCHIVE_URL=""
MEDIAS_DOWNLOADED=false

# Recuperer les informations de la release avec le tag specifique Raspy2DMD_Medias
MEDIAS_RELEASE=$(curl -s "${GITHUB_API_URL}/releases/tags/${MEDIAS_TAG}" 2>/dev/null || echo "")

if [ -n "$MEDIAS_RELEASE" ] && echo "$MEDIAS_RELEASE" | grep -q "tag_name"; then
    # Chercher l'archive Medias.7z dans les assets
    MEDIAS_ARCHIVE_URL=$(echo "$MEDIAS_RELEASE" | grep -o "\"browser_download_url\"[^,]*${MEDIAS_ARCHIVE_NAME}\"" | cut -d'"' -f4 | head -1)

    if [ -n "$MEDIAS_ARCHIVE_URL" ]; then
        log_substep "Archive trouvee : ${MEDIAS_ARCHIVE_NAME}"
        log_substep "Telechargement en cours..."

        if wget -q --show-progress "$MEDIAS_ARCHIVE_URL" -O "${TMP_DIR}/medias.7z" 2>/dev/null; then
            log_substep "Extraction de l'archive..."

            # Verifier si 7za est disponible
            if command -v 7za &> /dev/null; then
                7za x -o"${TMP_DIR}" -y "${TMP_DIR}/medias.7z" > /dev/null 2>&1

                # Copier les fichiers extraits vers /Medias
                if [ -d "${TMP_DIR}/Medias" ]; then
                    log_substep "Installation des fichiers Medias..."
                    mkdir -p "$MEDIAS_DIR"
                    cp -r "${TMP_DIR}/Medias/"* "$MEDIAS_DIR/" 2>/dev/null || true
                    MEDIAS_DOWNLOADED=true
                    log_info "Fichiers Medias installes depuis l'archive GitHub"
                fi
            else
                log_warn "7za non installe, impossible d'extraire l'archive"
            fi
        else
            log_warn "Echec du telechargement de l'archive Medias"
        fi
    else
        log_warn "Archive ${MEDIAS_ARCHIVE_NAME} non trouvee dans la release ${MEDIAS_TAG}"
    fi
else
    log_warn "Release ${MEDIAS_TAG} non trouvee sur GitHub"
fi

# =============================================================================
# CREATION DE L'ARBORESCENCE (COMPLETE OU DEPUIS ZERO)
# =============================================================================
log_info "Creation/completion de l'arborescence /Medias..."

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
# TELECHARGEMENT DES FICHIERS ESSENTIELS SI NON PRESENTS
# =============================================================================
if [ "$MEDIAS_DOWNLOADED" = false ]; then
    log_substep "Telechargement des fichiers essentiels depuis GitHub..."

    # Liste des fichiers essentiels a telecharger
    ESSENTIAL_FILES=(
        "Fonts/Impact.ttf"
        "Fonts/8bit.ttf"
        "Raspy2DMD/images/DMD/Raspy2DMD.png"
        "Raspy2DMD/images/HDMI/Raspy2DMD.png"
        "Raspy2DMD/update_gif/DMD/update.gif"
        "Raspy2DMD/update_gif/HDMI/update.gif"
        "Raspy2DMD/warn/NoInternet/DMD/NoInternet.gif"
        "Raspy2DMD/warn/NoIP/DMD/NoIp.gif"
        "Raspy2DMD/warn/RGBTest/DMD/rgb_test.png"
        "Raspy2DMD/warn/RGBTest/HDMI/rgb_test.png"
    )

    DOWNLOADED=0
    for file in "${ESSENTIAL_FILES[@]}"; do
        DEST_FILE="${MEDIAS_DIR}/${file}"

        if [ ! -f "$DEST_FILE" ]; then
            FILE_URL="${GITHUB_RAW_URL}/Medias/${file}"

            # Creer le dossier parent si necessaire
            mkdir -p "$(dirname "$DEST_FILE")"

            if curl -sSL "$FILE_URL" -o "$DEST_FILE" 2>/dev/null; then
                # Verifier que le fichier n'est pas une page d'erreur HTML
                if file "$DEST_FILE" | grep -qE "(image|font|TrueType)" 2>/dev/null; then
                    DOWNLOADED=$((DOWNLOADED + 1))
                else
                    rm -f "$DEST_FILE"
                fi
            fi
        fi
    done

    if [ $DOWNLOADED -gt 0 ]; then
        log_info "${DOWNLOADED} fichiers essentiels telecharges"
    fi

    # Si Impact.ttf n'existe toujours pas, chercher dans le systeme
    if [ ! -f "${MEDIAS_DIR}/Fonts/Impact.ttf" ]; then
        SYSTEM_FONT=$(find /usr/share/fonts -name "Impact*.ttf" 2>/dev/null | head -1)
        if [ -n "$SYSTEM_FONT" ]; then
            cp "$SYSTEM_FONT" "${MEDIAS_DIR}/Fonts/Impact.ttf"
            log_info "Police Impact.ttf copiee depuis le systeme"
        else
            # Utiliser une police de remplacement
            FALLBACK_FONT=$(find /usr/share/fonts -name "DejaVuSans-Bold.ttf" 2>/dev/null | head -1)
            if [ -n "$FALLBACK_FONT" ]; then
                cp "$FALLBACK_FONT" "${MEDIAS_DIR}/Fonts/Impact.ttf"
                log_warn "Police Impact.ttf remplacee par DejaVuSans-Bold"
            else
                log_warn "Aucune police trouvee - ajoutez Impact.ttf manuellement dans ${MEDIAS_DIR}/Fonts/"
            fi
        fi
    fi
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
# NETTOYAGE
# =============================================================================
rm -rf "$TMP_DIR"

# =============================================================================
# RESUME
# =============================================================================
echo ""
log_info "Arborescence Medias creee avec succes !"
echo ""

if [ "$MEDIAS_DOWNLOADED" = true ]; then
    echo -e "${GREEN}Les fichiers Medias ont ete telecharges depuis la release GitHub.${NC}"
else
    echo -e "${YELLOW}Les fichiers Medias n'ont pas pu etre telecharges automatiquement.${NC}"
    echo -e "${YELLOW}Vous devrez peut-etre ajouter manuellement certains fichiers.${NC}"
fi

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
