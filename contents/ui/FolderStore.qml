/*
    Favourite folders: stored as JSON in Plasmoid.configuration.favoriteFolders.
    Apps inside a folder stay normal favourites (so icons/launching keep working);
    they are only hidden from the top level of the Favourites view.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.plasmoid

QtObject {
    id: store

    property var favoritesModel: null

    // [{ id: string, name: string, apps: [favoriteId, ...] }]
    readonly property var list: parse(Plasmoid.configuration.favoriteFolders)

    // Folder tiles register here so FavoritesDragDispatcher can hit-test them
    property var dropTargets: []
    function registerDropTarget(item) {
        if (!dropTargets.includes(item)) {
            dropTargets.push(item);
        }
    }
    function unregisterDropTarget(item) {
        const i = dropTargets.indexOf(item);
        if (i >= 0) {
            dropTargets.splice(i, 1);
        }
    }

    // Ask the Favourites page to open a folder (editName: focus the name field)
    signal openRequested(string folderId, bool editName)

    function parse(text) {
        try {
            const value = JSON.parse(text || "[]");
            if (!Array.isArray(value)) {
                return [];
            }
            return value.filter(f => f && typeof f.id === "string" && Array.isArray(f.apps))
                        .map(f => ({ id: f.id, name: String(f.name ?? ""), apps: f.apps.map(String) }));
        } catch (e) {
            return [];
        }
    }

    function save(folders) {
        Plasmoid.configuration.favoriteFolders = JSON.stringify(folders);
    }

    function copy() {
        return JSON.parse(JSON.stringify(list));
    }

    function find(folderId) {
        return list.find(f => f.id === folderId) ?? null;
    }

    function folderOf(appId) {
        if (!appId) {
            return "";
        }
        for (const f of list) {
            if (f.apps.includes(appId)) {
                return f.id;
            }
        }
        return "";
    }

    function create(name, appIds) {
        const ids = appIds ?? [];
        const folders = copy();
        for (const f of folders) {
            f.apps = f.apps.filter(a => !ids.includes(a));
        }
        const folderId = "folder-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1e6).toString(36);
        folders.push({ id: folderId, name: name || i18n("New Folder"), apps: ids });
        save(folders);
        return folderId;
    }

    function rename(folderId, name) {
        const trimmed = String(name).trim();
        if (trimmed === "") {
            return;
        }
        const folders = copy();
        const f = folders.find(x => x.id === folderId);
        if (f && f.name !== trimmed) {
            f.name = trimmed;
            save(folders);
        }
    }

    // Change folder order (drag a folder tile)
    function moveFolder(from, to) {
        const folders = copy();
        if (from < 0 || from >= folders.length) {
            return;
        }
        to = Math.max(0, Math.min(folders.length - 1, to));
        if (from === to) {
            return;
        }
        const [f] = folders.splice(from, 1);
        folders.splice(to, 0, f);
        save(folders);
    }

    // Deleting a folder puts its apps back at the top level of Favourites.
    function remove(folderId) {
        save(copy().filter(f => f.id !== folderId));
    }

    // Makes sure the app is a favourite, then moves it into the folder.
    function addApp(folderId, appId) {
        if (!appId || !find(folderId)) {
            return;
        }
        if (favoritesModel && !favoritesModel.isFavorite(appId)) {
            favoritesModel.addFavorite(appId);
        }
        const folders = copy();
        for (const f of folders) {
            f.apps = f.apps.filter(a => a !== appId);
        }
        folders.find(x => x.id === folderId).apps.push(appId);
        save(folders);
    }

    // Takes the app out of whatever folder it is in (it stays a favourite).
    function removeApp(appId) {
        if (folderOf(appId) === "") {
            return;
        }
        const folders = copy();
        for (const f of folders) {
            f.apps = f.apps.filter(a => a !== appId);
        }
        save(folders);
    }

    function newFolderWith(appId) {
        if (appId && favoritesModel && !favoritesModel.isFavorite(appId)) {
            favoritesModel.addFavorite(appId);
        }
        const folderId = create(i18n("New Folder"), appId ? [appId] : []);
        openRequested(folderId, true);
        return folderId;
    }

    // Context menu entries for an app (used by AbstractKickoffItemDelegate)
    function actionsFor(appId) {
        if (!appId || !favoritesModel || !favoritesModel.enabled) {
            return [];
        }
        const current = folderOf(appId);
        const sub = [];
        for (const f of list) {
            if (f.id !== current) {
                sub.push({ text: f.name, icon: "folder", actionId: "_folder_move", actionArgument: { folderId: f.id, appId } });
            }
        }
        if (sub.length > 0) {
            sub.push({ type: "separator", actionId: "_folder_separator" });
        }
        sub.push({ text: i18n("New Folder"), icon: "folder-new", actionId: "_folder_new", actionArgument: { appId } });

        const actions = [{ text: current ? i18n("Move to Folder") : i18n("Add to Folder"), icon: "folder", subActions: sub }];
        if (current) {
            actions.push({ text: i18n("Remove from Folder"), icon: "folder-open", actionId: "_folder_takeout", actionArgument: { appId } });
        }
        return actions;
    }

    function handleAction(actionId, arg) {
        if (actionId === "_folder_move") {
            addApp(arg.folderId, arg.appId);
        } else if (actionId === "_folder_new") {
            newFolderWith(arg.appId);
        } else if (actionId === "_folder_takeout") {
            removeApp(arg.appId);
        }
    }
}
