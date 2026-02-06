# Raspy2DMD
**Système d'affichage DMD (Dot Matrix Display) pour Raspberry Pi en lien avec RaspyDarts, MQTT, Twitch, Recalbox, Domotique, etc**

Transformez votre Raspberry Pi en afficheur DMD pour fléchette, jeux d'arcade et projets d'affichage.

## ✨ Fonctionnalités

- 🎯 **Support multi-résolutions** : 128x32, 192x64 et formats personnalisés
- 🎨 **Affichage haute qualité** : Gifs, images, animations, texte, etc
- 🔈 **Lecture de son** : ogg
- 🎮 **Mini jeux intégrés** : Snake, Space Wars, Flappy Bird, Pong
- 🌐 **Interface web** : Configuration complète via navigateur
- 📱 **Bluetooth** : Contrôle à distance
- 🔄 **Mises à jour automatiques** : Toujours à jour
- ↔️ **Connectivité** : WiFi, Ethernet, USB et Bluetooth

## 📚 Documentation

👉 **[Documentation complète](https://rmdelcelier.github.io/Raspy2DMD/)**

## 🚀 Installation rapide

### Option 1 : Image SD pré-configurée (recommandé)

**La méthode la plus simple**

1. **Télécharger** l'image SD depuis https://raspydarts.wordpress.com/telechargement/ (Rubrique "Raspy2DMD" puis sur => DRIVE <=)
2. **Graver** avec votre logiciel préféré
3. **Relier** votre Raspberry Pi au réseau via l'ethernet ou au WiFi (création d'un fichier 'wpa_supplicant.conf'), ou en USB
4. **Insérer** la carte mini SD dans votre Raspberry Pi
4. **Démarrer** et accéder à `http://raspy2dmd.local/`

Plus d'information sur => https://raspydarts.wordpress.com/tutoriels-raspy2dmd/

### Option 2 : Installation automatique

**Sur un Raspberry Pi avec Raspberry Pi OS Lite (32-bit) - Trixie minimum - déjà installé**

```bash
curl -sSL https://raw.githubusercontent.com/rmdelcelier/raspy2dmd/main/scripts/install_raspy2dmd.sh | sudo bash
```

## 📋 Prérequis matériels

| Composant |  |
|-----------|---------|
| **Raspberry Pi** | Pi Zero WH (ou plus)|
| **Carte Interfacage DMD/Raspberry Pi** | MMWorkShop, AdaFruit, Smallcab |
| **Carte SD** | 8 GB Class 10 (ou plus)|
| **Alimentation** | 5V 3A (en fonction des panneaux) |

## 🔧 Configuration

Après installation, accéder à l'interface web (WiFi, Ethernet ou USB) :

```
http://raspy2dmd.local/
```

## 🔄 Mises à jour

Les mises à jour sont **automatiques** (mais désactivable) et vérifiées quotidiennement.

## 📄 Licence

Ce projet est distribué sous licence [MIT](LICENSE).

---

**Développé avec ❤️ pour la communauté des passionnés**
