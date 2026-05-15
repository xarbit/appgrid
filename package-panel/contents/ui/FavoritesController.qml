/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Routes favorites mutations to either AppFilterModel (local config-backed)
    or KAStatsFavoritesModel (KActivities-backed, shared across AppGrid
    instances). The mode is controlled by `useShared`.

    The shared model is owned externally (created in GridPanel via a Loader)
    and injected via `sharedModel` so this component stays decoupled from
    org.kde.plasma.private.kicker — which may not be present on every system.
*/

import QtQuick

QtObject {
    id: controller

    property bool useShared: false
    property var localModel: null   // AppFilterModel
    property var sharedModel: null  // KAStatsFavoritesModel, or null when unavailable

    readonly property bool sharedReady: sharedModel !== null && sharedModel !== undefined

    function isFavorite(storageId) {
        if (useShared && sharedReady)
            return sharedModel.isFavorite(storageId)
        return localModel ? localModel.isFavorite(storageId) : false
    }

    function toggle(storageId) {
        if (!storageId) return
        if (useShared && sharedReady) {
            if (sharedModel.isFavorite(storageId))
                sharedModel.removeFavorite(storageId)
            else
                sharedModel.addFavorite(storageId)
            return
        }
        if (localModel) localModel.toggleFavorite(storageId)
    }

    function swap(leftStorageId, rightStorageId) {
        if (!leftStorageId || !rightStorageId || leftStorageId === rightStorageId) return
        if (useShared && sharedReady) {
            const favs = sharedModel.favorites
            const li = favs.indexOf(leftStorageId)
            const ri = favs.indexOf(rightStorageId)
            if (li < 0 || ri < 0) return
            // KAStatsFavoritesModel.moveRow is a shift — emulate swap with two moves.
            if (li < ri) {
                sharedModel.moveRow(li, ri)
                sharedModel.moveRow(ri - 1, li)
            } else {
                sharedModel.moveRow(ri, li)
                sharedModel.moveRow(li - 1, ri)
            }
            return
        }
        if (localModel) localModel.swapFavorites(leftStorageId, rightStorageId)
    }

    function move(storageId, toIndex) {
        if (!storageId) return
        if (useShared && sharedReady) {
            const from = sharedModel.favorites.indexOf(storageId)
            if (from < 0 || from === toIndex) return
            sharedModel.moveRow(from, toIndex)
            return
        }
        if (localModel) localModel.moveFavorite(storageId, toIndex)
    }

    function favorites() {
        if (useShared && sharedReady) return sharedModel.favorites
        return localModel ? localModel.favoriteApps : []
    }
}
