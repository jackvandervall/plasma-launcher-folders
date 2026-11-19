/*
    iPhone-style open folder: the launcher behind is blurred and dimmed, the
    folder's apps appear in a rounded panel in the middle with an editable name.
    Click outside / Esc closes. Drag an app outside the panel to take it out.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

FocusScope {
    id: overlay

    // Items drawn blurred behind the overlay (siblings, never the overlay itself)
    property list<Item> blurSources

    property string folderId: ""
    readonly property bool isOpen: folderId !== ""
    readonly property var folder: kickoff.folders.find(folderId)
    readonly property alias panel: panel
    readonly property alias folderView: folderGrid
    property bool takeoutHint: false

    visible: opacity > 0
    opacity: isOpen ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
    }

    function open(id: string, editName: bool): void {
        folderId = id
        folderGrid.currentIndex = -1
        if (editName) {
            nameField.forceActiveFocus(Qt.ShortcutFocusReason)
            nameField.selectAll()
        } else {
            folderGrid.view.forceActiveFocus(Qt.OtherFocusReason)
        }
    }

    function close(): void {
        if (!isOpen) {
            return
        }
        commitName()
        folderId = ""
        kickoff.contentArea?.forceActiveFocus(Qt.OtherFocusReason)
    }

    function commitName(): void {
        if (folder && nameField.text.trim() !== "" && nameField.text.trim() !== folder.name) {
            kickoff.folders.rename(folderId, nameField.text)
        }
    }

    // Folder deleted (e.g. from elsewhere) -> close
    onFolderChanged: if (isOpen && !folder) { folderId = "" }

    Keys.onEscapePressed: close()

    // ---- Blurred, dimmed background -------------------------------------
    Repeater {
        model: overlay.blurSources
        delegate: MultiEffect {
            required property Item modelData
            // header and contentItem are direct children of the page the overlay
            // fills, so their own x/y are already in overlay coordinates (and stay live)
            x: modelData?.x ?? 0
            y: modelData?.y ?? 0
            width: modelData?.width ?? 0
            height: modelData?.height ?? 0
            visible: overlay.visible
            source: ShaderEffectSource {
                sourceItem: modelData
                live: overlay.visible
                // hide the sharp original so only the blurred copy shows
                hideSource: overlay.visible
            }
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: -0.1
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        opacity: overlay.takeoutHint ? 0.2 : 0.45
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }

    PC3.Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: panel.top
        anchors.bottomMargin: Kirigami.Units.largeSpacing
        visible: overlay.takeoutHint
        text: i18n("Drop to take it out of the folder")
        font.bold: true
    }

    // Click outside the panel closes; also swallows hover/wheel for the launcher behind
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: overlay.close()
        onWheel: wheel => wheel.accepted = true
    }

    // ---- The folder panel -----------------------------------------------
    Rectangle {
        id: panel

        readonly property real cell: KickoffSingleton.gridCellSize
        readonly property int appCount: folderGrid.count
        readonly property int columns: Math.max(3, Math.min(4, appCount, Math.floor((overlay.width - Kirigami.Units.gridUnit * 4) / cell)))
        readonly property int rows: Math.max(1, Math.min(3, Math.ceil(appCount / columns)))
        readonly property real pad: Kirigami.Units.largeSpacing * 2

        anchors.centerIn: parent
        width: columns * cell + pad * 2 + (kickoff.mayHaveGridWithScrollBar ? Kirigami.Units.gridUnit : 0)
        height: titleRow.implicitHeight + Kirigami.Units.largeSpacing + rows * cell + pad * 2

        radius: Kirigami.Units.cornerRadius * 5
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.96)
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

        scale: overlay.isOpen ? 1 : 0.85
        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack }
        }

        // keep clicks inside the panel from closing the folder
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: panel.pad
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                id: titleRow
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item { implicitWidth: deleteButton.implicitWidth }

                PC3.TextField {
                    id: nameField
                    Layout.fillWidth: true
                    horizontalAlignment: TextInput.AlignHCenter
                    text: overlay.folder?.name ?? ""
                    placeholderText: i18n("Folder name")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    font.bold: true
                    background: Rectangle {
                        radius: Kirigami.Units.cornerRadius * 2
                        color: Qt.alpha(Kirigami.Theme.textColor, nameField.activeFocus ? 0.10 : 0)
                    }
                    onAccepted: {
                        overlay.commitName()
                        folderGrid.view.forceActiveFocus(Qt.OtherFocusReason)
                    }
                    onEditingFinished: overlay.commitName()
                    Keys.onEscapePressed: overlay.close()
                }

                PC3.ToolButton {
                    id: deleteButton
                    icon.name: "edit-delete"
                    text: i18n("Delete folder (apps stay in Favourites)")
                    display: PC3.AbstractButton.IconOnly
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: {
                        const id = overlay.folderId
                        overlay.folderId = ""
                        kickoff.folders.remove(id)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                KickoffGridView {
                    id: folderGrid
                    anchors.fill: parent
                    focus: true
                    model: FavoritesProxy {
                        sourceModel: kickoff.rootModel.favoritesModel
                        folderId: overlay.folderId
                    }
                    // no hover header/footer strips inside the panel
                    header: null
                    footer: null
                    view.leftMargin: 0
                    view.rightMargin: 0
                    Keys.onEscapePressed: overlay.close()
                }

                PC3.Label {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: folderGrid.count === 0
                    text: i18n("This folder is empty.\nDrag apps onto it in Favourites, or right-click an app → Add to Folder.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    opacity: 0.7
                }
            }
        }
    }
}
