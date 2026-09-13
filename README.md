# LayerKeyApp

Transforme la touche **Menu** (AppsKey / `VK_APPS`, entre Alt droit et Ctrl droit) en **touche de calque maintenue** : tant que tu la maintiens, chaque touche du clavier déclenche une action personnalisée. Dès que tu relâches, le clavier redevient normal.

## Ce que ça fait

- **Maintenir Menu + une touche** → lance une action :
  - `url` : ouvre un lien dans le navigateur
  - `app` : lance une application (`.exe`)
  - `sound` : joue un son (`.wav` / `.mp3`)
  - `cmd` : exécute une ligne de commande
- **Interface graphique** de configuration (ajouter / modifier / supprimer / tester)
- **Icône dans la barre des tâches** : activer/désactiver le calque, ouvrir la config, démarrer avec Windows, quitter
- **Overlay** en bas à droite listant les raccourcis pendant que le calque est actif
- La touche Menu seule ne déclenche plus le menu contextuel Windows (sauf si le calque est désactivé)

## Prérequis

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (installé ici via `winget install AutoHotkey.AutoHotkey`)

## Lancer

Double-clique sur **`LayerKeyApp.bat`** (ou sur `LayerKeyApp.ahk` si l'association de fichiers AHK est active).
Une icône verte apparaît dans la barre des tâches → double-clic dessus pour ouvrir la configuration.

## Fichiers

| Fichier | Rôle |
|---|---|
| `LayerKeyApp.ahk` | Application principale (moteur, GUI, tray, démarrage Windows) |
| `json.ahk` | Lecture/écriture JSON (module réutilisable, testé en aller-retour) |
| `LayerKeyApp.bat` | Lanceur double-clic |
| `sounds/` | Sons du soundboard |

## Configuration

Stockée dans `%AppData%\LayerKey\config.json`. Éditable via l'interface (recommandé) ou à la main :

```json
{
  "trigger_key": "AppsKey",
  "mappings": [
    { "key": "y", "type": "url",   "target": "https://www.youtube.com/feed/subscriptions" },
    { "key": "g", "type": "url",   "target": "https://www.google.com" },
    { "key": "n", "type": "app",   "target": "notepad.exe" }
  ]
}
```

## État d'avancement (plan par phases)

- [x] Phase 1 — prototype touche de calque
- [x] Phase 2 — moteur dynamique lisant `config.json`
- [x] Phase 3 — interface graphique de configuration
- [x] Phase 4 — icône barre des tâches + démarrage avec Windows + overlay
- [ ] Phase 5 — packaging `.exe` (Ahk2Exe) + installeur (Inno Setup)
- [ ] Phase 6 — tests approfondis (plein écran / jeux) et finitions

## Avertissement jeux

Certains anti-triches (Vanguard, EasyAntiCheat, BattlEye…) détectent/bloquent les hooks clavier globaux. À tester au cas par cas pour les jeux compétitifs en ligne.
