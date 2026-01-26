#!/bin/bash
##############################################################################
# Raspy2DMD - Script de desinstallation
# Version : 1.0.0
# Auteur  : Remi DELCELIER
#
# Ce script desinstalle Raspy2DMD et nettoie le systeme
#
# Usage :
#   sudo bash uninstall_raspy2dmd.sh [--keep-medias] [--keep-database]
#
# Options :
#   --keep-medias   : Conserve le dossier /Medias
#   --keep-database : Conserve les bases de donnees MariaDB
#   --full          : Supprime TOUT (application + medias + bdd)
#
# IMPORTANT: Les fins de ligne doivent etre LF (Unix), pas CRLF (Windows)
##############################################################################

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================
INSTALL_DIR="/Raspy2DMD"
MEDIAS_DIR="/Medias"

# =============================================================================
# COULEURS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# =============================================================================
# OPTIONS
# =============================================================================
KEEP_MEDIAS=true
KEEP_DATABASE=true

for arg in "$@"; do
    case $arg in
        --keep-medias)
            KEEP_MEDIAS=true
            ;;
        --keep-database)
            KEEP_DATABASE=true
            ;;
        --full)
            KEEP_MEDIAS=false
            KEEP_DATABASE=false
            ;;
        --remove-medias)
            KEEP_MEDIAS=false
            ;;
        --remove-database)
            KEEP_DATABASE=false
            ;;
    esac
done

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

# =============================================================================
# BANNIERE
# =============================================================================
clear
echo -e "${RED}${BOLD}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║              DESINSTALLATION DE RASPY2DMD                        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# =============================================================================
# VERIFICATION ROOT
# =============================================================================
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit etre execute en tant que root (sudo)"
    exit 1
fi

# =============================================================================
# CONFIRMATION
# =============================================================================
echo ""
echo -e "${YELLOW}${BOLD}Ce script va :${NC}"
echo "  - Arreter tous les services Raspy2DMD"
echo "  - Supprimer le dossier ${INSTALL_DIR}"

if [ "$KEEP_MEDIAS" = false ]; then
    echo -e "  - ${RED}Supprimer le dossier ${MEDIAS_DIR}${NC}"
else
    echo -e "  - Conserver le dossier ${MEDIAS_DIR} (--keep-medias)"
fi

if [ "$KEEP_DATABASE" = false ]; then
    echo -e "  - ${RED}Supprimer les bases de donnees MariaDB (excluded, effects)${NC}"
else
    echo -e "  - Conserver les bases de donnees (--keep-database)"
fi

echo ""
echo -e "${YELLOW}Options disponibles :${NC}"
echo "  --keep-medias     : Conserver le dossier /Medias (par defaut)"
echo "  --keep-database   : Conserver les bases de donnees (par defaut)"
echo "  --remove-medias   : Supprimer le dossier /Medias"
echo "  --remove-database : Supprimer les bases de donnees"
echo "  --full            : Tout supprimer"
echo ""

read -p "Etes-vous sur de vouloir continuer ? (oui/NON) " -r
if [[ ! $REPLY =~ ^[Oo][Uu][Ii]$ ]]; then
    log_warn "Desinstallation annulee"
    exit 0
fi

# =============================================================================
# ARRET DES SERVICES
# =============================================================================
echo ""
log_info "Arret des services Raspy2DMD..."

# Arret via le script si disponible
if [ -f "${INSTALL_DIR}/StopAllRaspy2DMD.sh" ]; then
    bash "${INSTALL_DIR}/StopAllRaspy2DMD.sh" 2>/dev/null || true
fi

# Arret des processus restants
pkill -f "ServerRaspy2DMD" 2>/dev/null || true
pkill -f "node.*app.js" 2>/dev/null || true
pkill -f "ButtonsServer" 2>/dev/null || true
pkill -f "BluetoothServer" 2>/dev/null || true

# Arret et desactivation des services systemd
systemctl stop raspy2dmd-mqtt 2>/dev/null || true
systemctl stop raspy2dmd-web 2>/dev/null || true
systemctl disable raspy2dmd-mqtt 2>/dev/null || true
systemctl disable raspy2dmd-web 2>/dev/null || true

# Suppression des fichiers de service
rm -f /etc/systemd/system/raspy2dmd-mqtt.service 2>/dev/null || true
rm -f /etc/systemd/system/raspy2dmd-web.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

log_info "Services arretes"

# =============================================================================
# SUPPRESSION DU DOSSIER APPLICATION
# =============================================================================
if [ -d "$INSTALL_DIR" ]; then
    log_info "Suppression de ${INSTALL_DIR}..."
    rm -rf "$INSTALL_DIR"
    log_info "Dossier application supprime"
else
    log_warn "Dossier ${INSTALL_DIR} non trouve"
fi

# =============================================================================
# SUPPRESSION DU DOSSIER MEDIAS (SI DEMANDE)
# =============================================================================
if [ "$KEEP_MEDIAS" = false ]; then
    if [ -d "$MEDIAS_DIR" ]; then
        log_info "Suppression de ${MEDIAS_DIR}..."
        rm -rf "$MEDIAS_DIR"
        log_info "Dossier medias supprime"
    else
        log_warn "Dossier ${MEDIAS_DIR} non trouve"
    fi
else
    log_info "Dossier ${MEDIAS_DIR} conserve"
fi

# =============================================================================
# SUPPRESSION DES BASES DE DONNEES (SI DEMANDE)
# =============================================================================
if [ "$KEEP_DATABASE" = false ]; then
    log_info "Suppression des bases de donnees..."

    # Tentative avec mot de passe par defaut
    mysql -u root -praspberrypi -e "DROP DATABASE IF EXISTS excluded;" 2>/dev/null || true
    mysql -u root -praspberrypi -e "DROP DATABASE IF EXISTS effects;" 2>/dev/null || true

    # Tentative sans mot de passe
    mysql -u root -e "DROP DATABASE IF EXISTS excluded;" 2>/dev/null || true
    mysql -u root -e "DROP DATABASE IF EXISTS effects;" 2>/dev/null || true

    log_info "Bases de donnees supprimees"
else
    log_info "Bases de donnees conservees"
fi

# =============================================================================
# NETTOYAGE SUPPLEMENTAIRE
# =============================================================================
log_info "Nettoyage supplementaire..."

# Suppression du service Avahi
rm -f /etc/avahi/services/raspy2dmd.service 2>/dev/null || true
systemctl restart avahi-daemon 2>/dev/null || true

# Restauration du rc.local original si sauvegarde existe
if [ -f "/etc/rc.local.backup" ]; then
    mv /etc/rc.local.backup /etc/rc.local
    log_info "rc.local original restaure"
fi

# Suppression des fichiers temporaires
rm -rf /tmp/raspy2dmd_* 2>/dev/null || true

log_info "Nettoyage termine"

# =============================================================================
# RESUME
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}       Desinstallation terminee${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$KEEP_MEDIAS" = true ]; then
    echo -e "${BLUE}Note :${NC} Le dossier ${MEDIAS_DIR} a ete conserve."
    echo "       Pour le supprimer : sudo rm -rf ${MEDIAS_DIR}"
fi

if [ "$KEEP_DATABASE" = true ]; then
    echo -e "${BLUE}Note :${NC} Les bases de donnees ont ete conservees."
    echo "       Pour les supprimer :"
    echo "       mysql -u root -p -e 'DROP DATABASE excluded;'"
    echo "       mysql -u root -p -e 'DROP DATABASE effects;'"
fi

echo ""
echo -e "${YELLOW}Les dependances systeme (python3, nodejs, mariadb, etc.) n'ont pas ete supprimees.${NC}"
echo "Pour les supprimer, utilisez apt-get remove."
echo ""
