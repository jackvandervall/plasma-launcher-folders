/*
    Filtered view of the favourites model.
    folderId === ""  -> top level: favourites that are not inside any folder
    folderId !== ""  -> only the favourites inside that folder

    Re-exposes the functions the Kickoff views call on their model
    (trigger, moveRow, addFavoriteTo, favoritesModel) mapped to source rows.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kitemmodels as KItemModels

KItemModels.KSortFilterProxyModel {
    id: proxy

    property string folderId: ""
    readonly property bool isFavoritesProxy: true
    readonly property var favoritesModel: sourceModel
    readonly property var folderList: kickoff.folders.list
    readonly property int favoriteIdRole: sourceModel ? sourceModel.KItemModels.KRoleNames.role("favoriteId") : -1

    onFolderListChanged: invalidateFilter()
    onFolderIdChanged: invalidateFilter()

    filterRowCallback: (sourceRow, sourceParent) => {
        const appId = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), proxy.favoriteIdRole);
        if (proxy.folderId === "") {
            return kickoff.folders.folderOf(appId) === "";
        }
        const f = kickoff.folders.find(proxy.folderId);
        return !!f && f.apps.includes(appId);
    }

    function sourceRowFor(row: int): int {
        return mapToSource(index(row, 0)).row;
    }

    function trigger(row, actionId, argument) {
        return sourceModel.trigger(sourceRowFor(row), actionId, argument);
    }

    function moveRow(from: int, to: int): void {
        sourceModel.moveRow(sourceRowFor(from), sourceRowFor(to));
    }

    function isFavorite(appId) {
        return sourceModel.isFavorite(appId);
    }

    // Files/apps dropped in from outside the launcher
    function addFavoriteTo(appId, activity, targetIndex) {
        if (targetIndex === undefined || targetIndex < 0 || targetIndex >= count) {
            sourceModel.addFavoriteTo(appId, activity);
        } else {
            sourceModel.addFavoriteTo(appId, activity, sourceRowFor(targetIndex));
        }
        if (folderId !== "") {
            kickoff.folders.addApp(folderId, appId);
        }
    }
}
