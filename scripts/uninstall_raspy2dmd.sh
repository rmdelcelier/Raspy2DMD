#!/bin/bash
##############################################################################
# Raspy2DMD - Script de desinstallation
# Version : 1.0.0
# Auteur  : Remi DELCELIER
#
# Ce script desinstalle Raspy2DMD et nettoie le systeme
#
# Usage :
#   sudo bash uninstall_raspy2dmd.sh [--keep-medias] [--keep-database] [--full] [--sans-question]
#
# Options :
#   --keep-medias   : Conserve le dossier /Medias
#   --keep-database : Conserve les bases de donnees MariaDB
#   --full          : Supprime TOUT (application + medias + bdd) ; installation « Pico seul » :
#                     aussi l'utilisateur raspy2dmd, MariaDB et Node.js s'ils ont ete ajoutes par
#                     l'installation
#   --sans-question : Aucune confirmation (lancement sans terminal, par RaspyDarts) ; aussi
#                     avec RASPY2DMD_SANS_QUESTION=1
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
FULL=false
SANS_QUESTION=false
[ "${RASPY2DMD_SANS_QUESTION:-0}" = "1" ] && SANS_QUESTION=true

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
            FULL=true
            ;;
        --sans-question|--yes|-y)
            SANS_QUESTION=true
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
# Sans terminal (TERM absent : ssh non interactif, lancement par RaspyDarts), clear
# echoue et set -e arretait le script avant toute action
clear 2>/dev/null || true
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
echo "  --sans-question   : Ne rien demander (lancement automatique)"
echo ""

if [ "$SANS_QUESTION" = true ]; then
    log_info "Mode sans question : desinstallation lancee sans confirmation"
else
    # Sans terminal ni reponse (entree vide), read echoue : annulation propre, pas d'erreur
    read -p "Etes-vous sur de vouloir continuer ? (oui/NON) " -r || REPLY=""
    if [[ ! $REPLY =~ ^[Oo][Uu][Ii]$ ]]; then
        log_warn "Desinstallation annulee"
        exit 0
    fi
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

# Arret des processus restants. Motifs stricts : « pkill -f ServerRaspy2DMD » tuait aussi
# tout processus dont la ligne de commande contient ce mot, dont le shell ssh qui lance
# la desinstallation. Les [.] empechent aussi ces motifs de se reconnaitre eux-memes.
systemctl stop raspy2dmd.service 2>/dev/null || true
pkill -f 'bash [^ ]*/Raspy2DMD/ServerRaspy2DMD[A-Za-z]*[.]sh' 2>/dev/null || true
pkill -f 'python[0-9.]* [^ ]*/Raspy2DMD/' 2>/dev/null || true
pkill -f 'node [^ ]*/Raspy2DMD/web/app[.]js' 2>/dev/null || true

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
# SORTIE HDMI : CONSOLE LINUX ET IMAGE DE DEMARRAGE
# =============================================================================
# A faire AVANT la suppression de ${INSTALL_DIR} : le script qui retablit la console
# s'y trouve. Sans cela, l'ecran HDMI resterait sans messages de demarrage ni invite
# de connexion (cmdline.txt, config.txt et getty@tty1 modifies par Raspy2DMD).
pkill -f "hdmi_output.py" 2>/dev/null || true
# Installation « Pico seul » (--pico-seul) : console, cmdline.txt et ecran jamais modifies,
# rc.local et son service retires seulement s'ils ont ete crees par l'installation
PICO_SEUL_INSTALL=0; RC_LOCAL_CREE=0; RC_SERVICE_CREE=0
UTILISATEUR_CREE=0; MARIADB_INSTALLE=0; NODE_INSTALLE=0
if [ -f "${INSTALL_DIR}/.pico_seul" ]; then
    PICO_SEUL_INSTALL=1
    grep -q '^rc_local_cree=1' "${INSTALL_DIR}/.pico_seul" && RC_LOCAL_CREE=1
    grep -q '^rc_service_cree=1' "${INSTALL_DIR}/.pico_seul" && RC_SERVICE_CREE=1
    # Ecrits depuis la 1.6.2.3 : absents d'un marqueur plus ancien, rien n'est alors retire
    grep -q '^utilisateur_cree=1' "${INSTALL_DIR}/.pico_seul" && UTILISATEUR_CREE=1
    grep -q '^mariadb_installe=1' "${INSTALL_DIR}/.pico_seul" && MARIADB_INSTALLE=1
    grep -q '^node_installe=1' "${INSTALL_DIR}/.pico_seul" && NODE_INSTALLE=1
fi
if [ "$PICO_SEUL_INSTALL" = "1" ]; then
    log_info "Installation Pico seul : console Linux et cmdline.txt laisses tels quels"
elif [ -f "${INSTALL_DIR}/system/hdmi_console.sh" ]; then
    if bash "${INSTALL_DIR}/system/hdmi_console.sh" show 2>/dev/null; then
        log_info "Console Linux retablie sur l'ecran HDMI (effet complet au redemarrage)"
    else
        log_warn "Console Linux non retablie : verifiez console=tty1 dans cmdline.txt et 'systemctl enable getty@tty1'"
    fi
fi
rm -f /boot/firmware/cmdline.txt.r2d-orig /boot/cmdline.txt.r2d-orig 2>/dev/null || true

# Image de demarrage : le service pointerait sur un script supprime
systemctl disable raspy2dmd-splash.service 2>/dev/null || true
rm -f /etc/systemd/system/raspy2dmd-splash.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

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
# PARTAGES SAMBA DE RASPY2DMD
# =============================================================================
# Sections dont le chemin est sous /Medias (ajoutées par l'installation) ; les autres
# partages et [global] restent intacts (en Pico seul, Samba appartient à l'autre programme)
if [ -f /etc/samba/smb.conf ] && grep -qE '^[[:space:]]*path[[:space:]]*=[[:space:]]*/Medias(/|$)' /etc/samba/smb.conf; then
    cp -p /etc/samba/smb.conf /etc/samba/smb.conf.avant_desinstallation_raspy2dmd 2>/dev/null || true
    awk 'function flush(){ if (buf != "" && !drop) printf "%s", buf; buf=""; drop=0 } /^\[/{flush()} {buf = buf $0 "\n"; if ($0 ~ /^[ \t]*path[ \t]*=[ \t]*\/Medias(\/|$)/) drop=1} END{flush()}' \
        /etc/samba/smb.conf > /tmp/smb.conf.r2d && cat /tmp/smb.conf.r2d > /etc/samba/smb.conf
    rm -f /tmp/smb.conf.r2d
    systemctl reload smbd 2>/dev/null || true
    log_info "Partages Samba de Raspy2DMD retires (copie : /etc/samba/smb.conf.avant_desinstallation_raspy2dmd)"
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

    # Bases et utilisateur crees par l'installation (typos et l'utilisateur raspy2dmd
    # restaient en place). Root par socket (script lance en root), sinon anciens mots de passe.
    DB_SQL="DROP DATABASE IF EXISTS excluded; DROP DATABASE IF EXISTS effects; DROP DATABASE IF EXISTS typos;
DROP USER IF EXISTS 'raspy2dmd'@'localhost'; DROP USER IF EXISTS 'raspy2dmd'@'127.0.0.1';"
    mysql -u root -e "$DB_SQL" 2>/dev/null \
        || mysql -u root -praspberrypi -e "$DB_SQL" 2>/dev/null \
        || mysql -u raspy2dmd -praspy2dmd -e "$DB_SQL" 2>/dev/null || true

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

# Watchdog cron (installe par l'installation et les mises a jour) : sans cela, cron lance
# chaque minute un script supprime
if crontab -l 2>/dev/null | grep -q '/Raspy2DMD/system/watchdog.sh'; then
    crontab -l 2>/dev/null | grep -v '/Raspy2DMD/system/watchdog.sh' | crontab - 2>/dev/null || true
    log_info "Watchdog cron retire"
fi

# rc.local. /etc/rc.local.backup est la copie faite par les mises a jour (RC.LOCAL) : un
# ancien rc.local de Raspy2DMD, pas celui du systeme (l'installation sauvegarde sous
# rc.local.backup.<date>)
if [ "$RC_LOCAL_CREE" = "1" ]; then
    # Pico seul : il n'y avait pas de rc.local avant l'installation
    rm -f /etc/rc.local /etc/rc.local.backup 2>/dev/null || true
    log_info "rc.local cree par l'installation supprime"
elif [ -f "/etc/rc.local.backup" ]; then
    mv /etc/rc.local.backup /etc/rc.local
    log_info "rc.local original restaure"
fi
if [ "$RC_SERVICE_CREE" = "1" ]; then
    systemctl disable rc-local.service 2>/dev/null || true
    rm -f /etc/systemd/system/rc-local.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    log_info "rc-local.service cree par l'installation supprime"
fi

# Service de lancement anticipé du moteur
systemctl disable raspy2dmd.service 2>/dev/null || true
rm -f /etc/systemd/system/raspy2dmd.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

# Ecoute reseau de Mosquitto ajoutee par l'installation (port 1883, sans mot de passe).
# Sur une borne RaspyDarts, celui-ci repose son propre raspydarts.conf s'il en a besoin.
if [ -f /etc/mosquitto/conf.d/raspy2dmd.conf ]; then
    rm -f /etc/mosquitto/conf.d/raspy2dmd.conf
    systemctl restart mosquitto 2>/dev/null || true
    log_info "Configuration Mosquitto de Raspy2DMD retiree (raspy2dmd.conf)"
fi

# Installation « Pico seul » avec --full : ce que l'installation a ajoute a la machine
if [ "$FULL" = true ] && [ "$PICO_SEUL_INSTALL" = "1" ]; then
    if [ "$UTILISATEUR_CREE" = "1" ] && id raspy2dmd >/dev/null 2>&1; then
        pkill -u raspy2dmd 2>/dev/null || true
        sleep 1
        userdel -r raspy2dmd 2>/dev/null || userdel raspy2dmd 2>/dev/null || true
        log_info "Utilisateur raspy2dmd (cree par l'installation) supprime"
    fi
    if [ "$MARIADB_INSTALLE" = "1" ] && dpkg -s mariadb-server >/dev/null 2>&1; then
        systemctl stop mariadb 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq mariadb-server mariadb-client >/dev/null 2>&1 || true
        log_info "MariaDB (installe par l'installation) supprime"
    fi
    if [ "$NODE_INSTALLE" = "1" ]; then
        if dpkg -s nodejs >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq nodejs >/dev/null 2>&1 || true
            rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
        fi
        # Archive officielle decompressee dans /usr/local, liens dans /usr/bin
        for b in node npm npx corepack; do
            [ "$(readlink -f /usr/bin/$b 2>/dev/null)" = "$(readlink -f /usr/local/bin/$b 2>/dev/null)" ] && rm -f /usr/bin/$b
            rm -f /usr/local/bin/$b
        done
        rm -rf /usr/local/lib/node_modules /usr/local/include/node /usr/local/share/doc/node 2>/dev/null || true
        rm -f /usr/local/share/man/man1/node.1 /usr/local/share/systemtap/tapset/node.stp 2>/dev/null || true
        log_info "Node.js (installe par l'installation) supprime"
    fi
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
if [ "$FULL" = true ] && [ "$PICO_SEUL_INSTALL" = "1" ]; then
    echo -e "${YELLOW}Les autres dependances systeme (python3, mosquitto...) ont ete conservees : l'autre programme de cette machine peut s'en servir.${NC}"
else
    echo -e "${YELLOW}Les dependances systeme (python3, nodejs, mariadb, etc.) n'ont pas ete supprimees.${NC}"
    echo "Pour les supprimer, utilisez apt-get remove."
fi
echo ""
