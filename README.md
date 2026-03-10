# Raspy2DMD
**Système d'affichage DMD (Dot Matrix Display) pour Raspberry Pi en lien avec RaspyDarts, MQTT, Twitch, Recalbox, Domotique, etc**

Transformez votre Raspberry Pi en afficheur DMD pour fléchette, jeux d'arcade et projets d'affichage.

## ✨ Fonctionnalités

- 🎯 **Support multi-résolutions** : 128x32, 192x64 et formats personnalisés
- 🎨 **Affichage haute qualité** : Gifs, images, animations, texte, etc
- 🔈 **Lecture de son** : ogg, mp3, flac, wav
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

1. **Télécharger** Raspberry Pi Imager v2.0.6 (ou plus)
2. **Exécuter** Raspberry Pi Imager
3. **Cliquer** sur le bouton en bas à gauche ("Options App")
4. **Copier/coller** le lien ci-contre dans la case "Utiliser une URL personnalisée" : https://raw.githubusercontent.com/rmdelcelier/Raspy2DMD/main/rpi-imager.json
5. **Paramétrer** avec Raspberry Pi Imager
6. **Graver** avec Raspberry Pi Imager
7. **Relier** votre Raspberry Pi au réseau ou en USB
8. **Insérer** la carte mini SD dans votre Raspberry Pi
9. **Démarrer** et accéder à `http://raspy2dmd.local/`

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
