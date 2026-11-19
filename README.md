# Application Launcher with Folders (KDE Plasma 6)

KDE Plasma's Application Launcher, plus **iPhone-style folders in Favourites**.

<!-- Add a screenshot here: docs/screenshot.png -->

## Features

- **Make a folder** by dragging one favourite onto the middle of another, by dropping an app on the
  **New Folder** tile that appears while you drag, or by right-clicking empty space → **New Folder**.
- **Open a folder** with a click: it opens on top, with the launcher behind it blurred.
  Rename it by clicking its name. Close it by clicking outside or pressing Esc.
- **Add apps** by dragging them onto a folder, or right-click an app → **Add to Folder** (this works from
  All Applications too).
- **Hold an app over a folder** for a moment and the folder opens, so you can drop the app at a specific spot.
- **Take an app out** by dragging it outside the open folder, or right-click → **Remove from Folder**.
- **Rearrange folders** by dragging them.
- **Delete a folder** with the bin icon in the open folder, or right-click it. Its apps go back to Favourites.

Everything else works exactly like the normal Application Launcher.

## Install

Requires KDE Plasma 6 (developed and tested on Plasma 6.8).

```bash
git clone https://github.com/jackvandervall/plasma-launcher-folders.git
cd plasma-launcher-folders
./install.sh --replace
```

`--replace` swaps your panel's Application Launcher for this one **in place**, so your favourites and
launcher settings are kept. It backs up your Plasma config first, and the panel briefly disappears while
Plasma restarts.

Prefer to do it by hand? Run `./install.sh`, then right-click your launcher → **Show Alternatives** →
**Application Launcher (with Folders)**. Your favourites then start fresh, because Plasma stores them
per widget.

### Go back to the stock launcher

```bash
./install.sh --restore
./install.sh --uninstall
```

### Update

```bash
git pull && ./install.sh
```

## How it works

- This is a copy of Plasma's own launcher (Kickoff, from `plasma-desktop` 6.8.2), so **Plasma updates
  never touch it, and it doesn't receive KDE's launcher fixes either**. A large future Plasma release
  could break it. If that happens, `./install.sh --restore` gives you the stock launcher back.
- Folders are stored in the widget's settings as JSON (`favoriteFolders`). Apps in a folder stay
  normal favourites; they're just hidden from the top level.
- The folder code lives in `contents/ui/`: `FolderStore.qml`, `FavoritesProxy.qml`, `FolderStrip.qml`,
  `FolderTile.qml`, `FolderOverlay.qml` and `FavoritesDragDispatcher.qml`, plus small changes to
  upstream files (`ApplicationsPage.qml`, `FullRepresentation.qml`, `AbstractKickoffItemDelegate.qml`,
  `KickoffGridDelegate.qml`, `ActionMenu.qml`, `main.qml`, `contents/config/main.xml`).

## Credits and license

Based on **Kickoff**, the KDE Plasma Application Launcher, by Martin Gräßlin, Mikel Johnson, Noah Davis,
Eike Hein, Nate Graham and the other KDE contributors
([source](https://invent.kde.org/plasma/plasma-desktop/-/tree/master/applets/kickoff)).
This is an independent project and is not affiliated with or endorsed by KDE.

Licensed under the GNU GPL, version 2 or later (see `LICENSE`). Some files are LGPL-2.0-or-later,
as marked in their headers; full texts are in `LICENSES/`.
