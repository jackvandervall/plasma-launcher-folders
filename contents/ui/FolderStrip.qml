/*
    Row(s) of folder tiles shown above the favourite apps.
    Used as the header of the Favourites grid/list so it scrolls with it.
    While an app is being dragged, a "New Folder" drop target is added.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: strip

    // The header is parented to the view's contentItem
    readonly property Flickable targetView: (parent && parent.parent instanceof Flickable) ? parent.parent : null
    signal openFolder(string folderId, bool editName)

    readonly property bool dragging: !!kickoff.dragSource.sourceItem
        && (kickoff.dragSource.sourceItem.model?.favoriteId ?? "") !== ""
    readonly property bool hasContent: kickoff.folders.list.length > 0 || dragging

    width: targetView ? targetView.width - targetView.leftMargin - targetView.rightMargin : 0
    height: hasContent ? flow.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0
    visible: hasContent

    Flow {
        id: flow
        width: Math.floor(strip.width / KickoffSingleton.gridCellSize) * KickoffSingleton.gridCellSize
        x: strip.targetView instanceof GridView ? 0 : Math.round((strip.width - width) / 2)

        Repeater {
            model: kickoff.folders.list
            delegate: FolderTile {
                id: folderTile
                required property var modelData
                required property int index
                folderId: modelData.id
                name: modelData.name
                beingMoved: strip.moveFrom === index
                onOpenRequested: editName => strip.openFolder(folderId, editName)
                onMoveStarted: {
                    strip.moveFrom = index
                    strip.moveTo = index
                    folderTile.grabToImage(result => ghost.source = result.url)
                }
                onMoveUpdated: scenePos => strip.updateMove(scenePos)
                onMoveFinished: strip.finishMove()
            }
        }

        FolderTile {
            visible: strip.dragging
            folderId: ""
        }
    }

    //BEGIN rearranging folders
    property int moveFrom: -1
    property int moveTo: -1     // insertion slot 0..count
    readonly property real cell: KickoffSingleton.gridCellSize
    readonly property int columns: Math.max(1, Math.floor(flow.width / cell))

    function updateMove(scenePos: point): void {
        const p = flow.mapFromItem(null, scenePos.x, scenePos.y)
        ghost.x = flow.x + p.x - ghost.width / 2
        ghost.y = flow.y + p.y - ghost.height / 2
        const n = kickoff.folders.list.length
        const col = Math.max(0, Math.min(columns, Math.round(p.x / cell)))
        const row = Math.max(0, Math.floor(p.y / cell))
        moveTo = Math.max(0, Math.min(n, row * columns + col))
    }

    function finishMove(): void {
        const from = moveFrom
        const slot = moveTo
        moveFrom = -1
        moveTo = -1
        ghost.source = ""
        if (from < 0 || slot < 0) {
            return
        }
        const to = slot > from ? slot - 1 : slot
        if (to !== from) {
            Qt.callLater(() => kickoff.folders.moveFolder(from, to))
        }
    }

    // where the folder will land
    Rectangle {
        visible: strip.moveFrom >= 0 && strip.moveTo >= 0
        z: 5
        width: 3
        radius: 1.5
        height: strip.cell * 0.8
        color: Kirigami.Theme.highlightColor
        readonly property int slotCol: strip.moveTo % strip.columns
        readonly property int slotRow: Math.floor(strip.moveTo / strip.columns)
        // the end of a full row shows at the right edge of that row
        readonly property bool atRowEnd: slotCol === 0 && strip.moveTo > 0 && strip.moveTo === kickoff.folders.list.length && strip.moveTo % strip.columns === 0
        x: flow.x + (atRowEnd ? strip.columns * strip.cell : slotCol * strip.cell) - width / 2
        y: flow.y + (atRowEnd ? slotRow - 1 : slotRow) * strip.cell + strip.cell * 0.1
    }

    // picture of the folder that follows the pointer
    Image {
        id: ghost
        z: 6
        visible: strip.moveFrom >= 0 && source != ""
        width: strip.cell
        height: strip.cell
        opacity: 0.9
    }
    //END rearranging folders

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        x: Kirigami.Units.smallSpacing
        width: flow.width - Kirigami.Units.smallSpacing * 2
        height: 1
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        visible: strip.hasContent
    }
}
