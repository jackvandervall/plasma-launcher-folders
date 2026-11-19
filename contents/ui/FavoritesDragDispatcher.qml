/*
    One drop area on top of the whole launcher that handles every drag of a
    favourite (top level or inside a folder):
      - over a folder tile          -> put the app in that folder
                                       (hold still for a moment -> the folder opens)
      - over the "New Folder" tile  -> make a folder with the app
      - over the middle of an app   -> make a folder with both apps
      - over the edge of an app     -> reorder
      - in an open folder (dragged from inside it): inside -> reorder, outside -> take out
      - in an open folder (dragged from Favourites): inside -> drop it in at that spot,
                                       outside for a moment -> the folder closes again
      - anywhere else               -> remove from Favourites (upstream behaviour)
    Drags of non-favourites are ignored so the stock drop areas handle them.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

DropArea {
    id: root

    readonly property Item draggedItem: kickoff.dragSource.sourceItem
    readonly property var sourceView: draggedItem?.view ?? null
    readonly property bool isFavoriteDrag: !!draggedItem && sourceView?.model?.isFavoritesProxy === true
    readonly property bool isFolderDrag: isFavoriteDrag && (sourceView?.model?.folderId ?? "") !== ""
    readonly property string appId: draggedItem?.model?.favoriteId ?? ""
    readonly property Item overlay: kickoff.folderOverlay

    // Undo list for reorders (like KickoffDropArea), so dropping outside reverts them
    property var dragMoves: []
    property Item hoverTarget: null     // folder tile under the pointer
    property Item combineTarget: null   // app delegate under the pointer (make a folder)
    property Item springTarget: null    // folder tile we are waiting on to open
    property string mode: ""   // "folder", "combine", "reorder", "inside", "intofolder", "takeout", "remove", "none"

    // Hold an app over a folder -> it opens (spring-loaded folders)
    Timer {
        id: springTimer
        interval: 650
        onTriggered: {
            if (root.springTarget && root.springTarget === root.hoverTarget && root.overlay) {
                const folderId = root.springTarget.folderId
                root.springTarget = null
                root.setHover(null)
                root.revertMoves()
                root.overlay.open(folderId, false)
            }
        }
    }

    // Dragged a favourite out of a spring-opened folder -> close it again
    Timer {
        id: closeTimer
        interval: 500
        onTriggered: {
            if (root.overlay?.isOpen && root.mode === "none") {
                root.overlay.close()
            }
        }
    }

    function folderTargetAt(x: real, y: real): Item {
        for (const t of kickoff.folders.dropTargets) {
            if (!t || !t.visible || t.width <= 0) {
                continue
            }
            if (t.contains(t.mapFromItem(root, x, y))) {
                return t
            }
        }
        return null
    }

    function setHover(t: Item): void {
        if (hoverTarget === t) {
            return
        }
        if (hoverTarget) {
            hoverTarget.dropHover = false
        }
        hoverTarget = t
        if (t) {
            t.dropHover = true
        }
    }

    function setCombine(d: Item): void {
        if (combineTarget === d) {
            return
        }
        if (combineTarget) {
            combineTarget.combineHover = false
        }
        combineTarget = d
        if (d) {
            d.combineHover = true
        }
    }

    function inside(item: Item, x: real, y: real): bool {
        return !!item && item.visible && item.contains(item.mapFromItem(root, x, y))
    }

    // App delegate whose middle (icon area) is under the pointer, or null
    function combineCandidateAt(x: real, y: real): Item {
        const view = sourceView
        if (!view || isFolderDrag) {
            return null
        }
        const pos = view.contentItem.mapFromItem(root, x, y)
        const idx = view.indexAt(pos.x, pos.y)
        if (idx < 0 || idx === draggedItem.index) {
            return null
        }
        const d = view.itemAtIndex(idx)
        if (!d || !d.model?.favoriteId) {
            return null
        }
        const p = d.mapFromItem(root, x, y)
        const inMiddle = Math.abs(p.x - d.width / 2) < d.width * 0.28
                      && Math.abs(p.y - d.height * 0.4) < d.height * 0.28
        return inMiddle ? d : null
    }

    function tryReorder(x: real, y: real): void {
        const view = sourceView
        if (!view || view.move?.running || view.moveDisplaced?.running) {
            return
        }
        const pos = view.contentItem.mapFromItem(root, x, y)
        const targetIndex = view.indexAt(pos.x, pos.y)
        const sourceIndex = draggedItem.index
        if (targetIndex >= 0 && sourceIndex >= 0 && targetIndex !== sourceIndex) {
            dragMoves.push([sourceIndex, targetIndex])
            view.model.moveRow(sourceIndex, targetIndex)
            view.currentIndex = draggedItem.index
        }
    }

    function revertMoves(): void {
        const view = sourceView
        while (dragMoves.length > 0) {
            const [start, end] = dragMoves.pop()
            view?.model?.moveRow(end, start)
        }
    }

    function update(x: real, y: real): void {
        let newMode = "remove"
        let target = null
        let combine = null

        if (overlay && overlay.isOpen) {
            const inPanel = inside(overlay.panel, x, y)
            if (isFolderDrag) {
                newMode = inPanel ? "inside" : "takeout"
            } else {
                newMode = inPanel ? "intofolder" : "none"
            }
        } else {
            target = folderTargetAt(x, y)
            if (target && (target.folderId === "" || kickoff.folders.folderOf(appId) !== target.folderId)) {
                newMode = "folder"
            } else if (target) {
                newMode = "none"
                target = null
            } else if (inside(sourceView, x, y)) {
                combine = combineCandidateAt(x, y)
                newMode = combine ? "combine" : "reorder"
            }
        }

        setHover(target)
        setCombine(combine)
        mode = newMode

        // spring-loaded folder: start waiting when we arrive on a (real) folder
        if (target && target.folderId !== "") {
            if (springTarget !== target) {
                springTarget = target
                springTimer.restart()
            }
        } else {
            springTarget = null
            springTimer.stop()
        }

        if (newMode === "none" && overlay?.isOpen && !isFolderDrag) {
            if (!closeTimer.running) {
                closeTimer.restart()
            }
        } else {
            closeTimer.stop()
        }

        if (overlay) {
            overlay.takeoutHint = (newMode === "takeout")
        }
        draggedItem.removalPlaceholderActive = (newMode === "remove")
        if (newMode === "reorder" || newMode === "inside") {
            tryReorder(x, y)
        }
    }

    function reset(): void {
        setHover(null)
        setCombine(null)
        springTarget = null
        springTimer.stop()
        closeTimer.stop()
        mode = ""
        if (overlay) {
            overlay.takeoutHint = false
        }
        if (draggedItem) {
            draggedItem.removalPlaceholderActive = false
        }
    }

    // Put appId at position targetIndex of the open folder's grid
    function placeInOpenFolder(id: string, targetIndex: int): void {
        const view = overlay?.folderView?.view
        const model = view?.model
        if (!model || targetIndex < 0) {
            return
        }
        for (let row = 0; row < model.count; ++row) {
            if (model.data(model.index(row, 0), model.favoriteIdRole) === id) {
                if (row !== targetIndex) {
                    model.moveRow(row, Math.min(targetIndex, model.count - 1))
                }
                return
            }
        }
    }

    onEntered: drag => {
        if (!isFavoriteDrag) {
            drag.accepted = false
            return
        }
        dragMoves = []
        drag.accept(Qt.MoveAction)
        update(drag.x, drag.y)
    }

    onPositionChanged: drag => {
        if (!isFavoriteDrag) {
            return
        }
        drag.accept(Qt.MoveAction)
        update(drag.x, drag.y)
    }

    onExited: {
        if (isFavoriteDrag) {
            revertMoves()
        }
        reset()
    }

    onDropped: drop => {
        if (!isFavoriteDrag) {
            drop.accepted = false
            return
        }
        update(drop.x, drop.y)
        const id = appId
        const target = hoverTarget
        const combine = combineTarget
        const currentMode = mode
        reset()

        if (currentMode === "folder" && target) {
            revertMoves()
            const folderId = target.folderId
            Qt.callLater(() => folderId === "" ? kickoff.folders.newFolderWith(id) : kickoff.folders.addApp(folderId, id))
        } else if (currentMode === "combine" && combine) {
            const otherId = String(combine.model.favoriteId)
            Qt.callLater(() => {
                const folderId = kickoff.folders.create(i18n("New Folder"), [otherId, id])
                kickoff.folders.openRequested(folderId, true)
            })
        } else if (currentMode === "intofolder") {
            revertMoves()
            const folderId = overlay.folderId
            const view = overlay.folderView.view
            const pos = view.contentItem.mapFromItem(root, drop.x, drop.y)
            const targetIndex = view.indexAt(pos.x, pos.y)
            Qt.callLater(() => {
                kickoff.folders.addApp(folderId, id)
                Qt.callLater(() => placeInOpenFolder(id, targetIndex))
            })
        } else if (currentMode === "takeout") {
            Qt.callLater(() => kickoff.folders.removeApp(id))
        } else if (currentMode === "remove") {
            revertMoves()
            Qt.callLater(() => {
                kickoff.folders.removeApp(id)
                kickoff.rootModel.favoritesModel.removeFavorite(id)
            })
        } else if (currentMode === "none") {
            revertMoves()
        }
        dragMoves = []
        drop.accept(Qt.MoveAction)
    }
}
