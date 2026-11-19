/*
    A folder in Favourites: 2x2 preview of the apps inside + name.
    Click opens it, right-click for Open/Rename/Delete.
    Drops are handled by FavoritesDragDispatcher (this tile registers itself
    as a drop target and shows dropHover).
    With folderId === "" it is the "New Folder" drop target shown while dragging.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: tile

    property string folderId: ""
    property string name: ""
    readonly property bool isNewFolderTarget: folderId === ""
    property bool dropHover: false   // set by FavoritesDragDispatcher

    property bool beingMoved: false  // this folder is being dragged to a new spot

    signal openRequested(bool editName)
    signal moveStarted()
    signal moveUpdated(point scenePos)
    signal moveFinished()

    opacity: beingMoved ? 0.3 : 1

    width: KickoffSingleton.gridCellSize
    height: KickoffSingleton.gridCellSize

    Component.onCompleted: kickoff.folders.registerDropTarget(tile)
    Component.onDestruction: kickoff.folders.unregisterDropTarget(tile)

    Accessible.role: Accessible.Button
    Accessible.name: isNewFolderTarget ? i18n("New Folder") : i18n("Folder: %1", name)
    activeFocusOnTab: !isNewFolderTarget
    Keys.onReturnPressed: tile.openRequested(false)
    Keys.onEnterPressed: tile.openRequested(false)
    Keys.onMenuPressed: menu.open(0, 0)

    PlasmaExtras.Highlight {
        anchors.fill: parent
        visible: mouseArea.containsMouse || tile.activeFocus
        hovered: true
        pressed: mouseArea.pressed
        active: true
    }

    FavoritesProxy {
        id: previewModel
        sourceModel: kickoff.rootModel.favoritesModel
        folderId: tile.isNewFolderTarget ? "\u0000none" : tile.folderId
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: KickoffSingleton.listItemMetrics.margins.left
        anchors.rightMargin: KickoffSingleton.listItemMetrics.margins.right
        anchors.topMargin: Kirigami.Units.smallSpacing * 2
        anchors.bottomMargin: Kirigami.Units.smallSpacing * 2
        spacing: KickoffSingleton.fontMetrics.descent

        Rectangle {
            id: box
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
            implicitWidth: Kirigami.Units.iconSizes.large
            implicitHeight: Kirigami.Units.iconSizes.large
            radius: Kirigami.Units.cornerRadius * 3
            color: tile.dropHover ? Qt.alpha(Kirigami.Theme.highlightColor, 0.45) : Qt.alpha(Kirigami.Theme.textColor, 0.12)
            border.width: tile.isNewFolderTarget || tile.dropHover ? 1 : 0
            border.color: tile.dropHover ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.5)
            scale: tile.dropHover ? 1.18 : 1
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

            Grid {
                anchors.centerIn: parent
                visible: !tile.isNewFolderTarget && previewModel.count > 0
                columns: 2
                spacing: Math.round(box.width * 0.06)
                readonly property real cell: Math.floor((box.width - spacing * 3) / 2)

                Repeater {
                    model: previewModel
                    delegate: Kirigami.Icon {
                        required property int index
                        required property var decoration
                        visible: index < 4
                        width: visible ? parent.cell : 0
                        height: visible ? parent.cell : 0
                        source: decoration
                        animated: false
                    }
                }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(box.width * 0.7)
                height: width
                visible: tile.isNewFolderTarget || previewModel.count === 0
                source: tile.isNewFolderTarget ? "folder-new" : "folder"
                animated: false
            }
        }

        PC3.Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.fillWidth: true
            Layout.preferredHeight: lineCount === 1 ? implicitHeight * 2 : implicitHeight
            text: tile.isNewFolderTarget ? i18n("New Folder") : tile.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: !tile.isNewFolderTarget
        onPressed: mouse => {
            tile.forceActiveFocus(Qt.MouseFocusReason)
            if (mouse.button === Qt.RightButton) {
                menu.open(mouse.x, mouse.y)
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                tile.openRequested(false)
            }
        }
    }

    // Drag a folder to rearrange folders
    DragHandler {
        id: moveHandler
        target: null
        enabled: !tile.isNewFolderTarget
        // don't let the scrolling grid steal the drag
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onActiveChanged: active ? tile.moveStarted() : tile.moveFinished()
        onCentroidChanged: if (active) { tile.moveUpdated(centroid.scenePosition) }
    }

    PlasmaExtras.Menu {
        id: menu
        visualParent: tile
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("Open")
            icon: "folder-open"
            onClicked: tile.openRequested(false)
        }
        PlasmaExtras.MenuItem {
            text: i18n("Rename…")
            icon: "edit-rename"
            onClicked: tile.openRequested(true)
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Delete Folder (apps stay in Favourites)")
            icon: "edit-delete"
            onClicked: kickoff.folders.remove(tile.folderId)
        }
    }
}
