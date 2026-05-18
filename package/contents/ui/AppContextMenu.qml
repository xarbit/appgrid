/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Right-click context menu for grid items: favorite, pin, add to desktop, edit, hide.
*/

import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import "favoriteid.js" as FavoriteId

PlasmaComponents.Menu {
    id: contextMenu

    Kicker.ProcessRunner { id: processRunner }
    Kicker.ContainmentInterface { id: containmentInterface }

    // Plasmoid root. Deliberately `var`, not typed as PlasmoidItem,
    // for two reasons: typing it would force every consumer to import
    // `org.kde.plasma.plasmoid`, and keeping the contract structural lets
    // tests pass plain QtObject mocks that expose the same properties
    // (isDragInFlight, …).
    property var appletInterface: null
    property var appsModel: null
    property var sharedFavoritesModel: null

    property int popupIndex: -1
    property string popupStorageId: ""
    property string popupDesktopFile: ""
    property bool popupIsFavorite: false

    property var popupActions: []

    // Multi-select payload — non-empty when the right-clicked item belongs
    // to an active selection of 2+ favorites. In that case the menu hides
    // single-item actions (pin/desktop/edit/hide/jumplist) since they don't
    // generalise cleanly, and the "Remove from Favorites" entry becomes a
    // batch op covering every selected sid.
    property var popupSelectedSids: []
    readonly property bool isMultiSelect: popupSelectedSids.length >= 2

    function showForApp(index, storageId, desktopFile, selectedSids) {
        popupIndex = index
        popupStorageId = storageId
        popupDesktopFile = desktopFile
        popupSelectedSids = selectedSids || []
        const prefixed = FavoriteId.toPrefixed(storageId)
        popupIsFavorite = sharedFavoritesModel
                          ? sharedFavoritesModel.isFavorite(prefixed)
                          : false
        popupActions = isMultiSelect ? [] : (Plasmoid.appActions(storageId) || [])
        popup()
    }

    // -- Application-defined actions (jumplist) --
    Repeater {
        model: contextMenu.popupActions
        delegate: PlasmaComponents.MenuItem {
            required property var modelData
            required property int index
            icon.name: modelData.icon || ""
            text: modelData.text
            onClicked: {
                Plasmoid.launchAppAction(contextMenu.popupStorageId, index)
                contextMenu.close()
            }
        }
    }

    // PlasmaComponents.Menu sizes itself from each child's `implicitHeight`,
    // and visible=false alone does NOT collapse the row — empty space leaks
    // into the menu wherever a gated item lives. Every conditionally-shown
    // item below pins `height: visible ? implicitHeight : 0` so hidden rows
    // contribute zero vertical space. Same trick applied to separators.

    // Bulk "Remove N favorites" — shown when the right-clicked item is
    // itself a favorite (matching the popup direction the user expects).
    // Removal iterates every selected sid that's currently in favorites
    // and skips ones that aren't, so a mixed selection works idempotently.
    PlasmaComponents.MenuItem {
        icon.name: "bookmark-remove"
        text: i18ndp("dev.xarbit.appgrid",
                     "Remove %1 favorite", "Remove %1 favorites",
                     contextMenu.popupSelectedSids.length)
        visible: contextMenu.isMultiSelect && contextMenu.popupIsFavorite
        height: visible ? implicitHeight : 0
        enabled: !(contextMenu.appletInterface
                   && contextMenu.appletInterface.isDragInFlight)
        onClicked: {
            if (!contextMenu.sharedFavoritesModel) return
            const sids = contextMenu.popupSelectedSids
            for (var i = 0; i < sids.length; ++i) {
                const prefixed = FavoriteId.toPrefixed(sids[i])
                if (contextMenu.sharedFavoritesModel.isFavorite(prefixed))
                    contextMenu.sharedFavoritesModel.removeFavorite(prefixed)
            }
        }
        Accessible.name: text
        Accessible.role: Accessible.MenuItem
    }

    // Bulk "Add N to Favorites" — shown when the right-clicked item is not
    // a favorite (selection drawn from All / category view). Already-faved
    // sids in a mixed selection are skipped.
    PlasmaComponents.MenuItem {
        icon.name: "bookmark-new"
        text: i18ndp("dev.xarbit.appgrid",
                     "Add %1 to Favorites", "Add %1 to Favorites",
                     contextMenu.popupSelectedSids.length)
        visible: contextMenu.isMultiSelect && !contextMenu.popupIsFavorite
        height: visible ? implicitHeight : 0
        enabled: !(contextMenu.appletInterface
                   && contextMenu.appletInterface.isDragInFlight)
        onClicked: {
            if (!contextMenu.sharedFavoritesModel) return
            const sids = contextMenu.popupSelectedSids
            for (var i = 0; i < sids.length; ++i) {
                const prefixed = FavoriteId.toPrefixed(sids[i])
                if (!contextMenu.sharedFavoritesModel.isFavorite(prefixed))
                    contextMenu.sharedFavoritesModel.addFavorite(prefixed)
            }
        }
        Accessible.name: text
        Accessible.role: Accessible.MenuItem
    }

    PlasmaComponents.MenuItem {
        icon.name: contextMenu.popupIsFavorite ? "bookmark-remove" : "bookmark-new"
        text: contextMenu.popupIsFavorite ? i18nd("dev.xarbit.appgrid", "Remove from Favorites") : i18nd("dev.xarbit.appgrid", "Add to Favorites")
        visible: !contextMenu.isMultiSelect
        height: visible ? implicitHeight : 0
        // Disabled while a drag-reorder is mid-flight to avoid clobbering
        // KAStats state and stale-grabbing the in-progress move.
        enabled: !(contextMenu.appletInterface
                   && contextMenu.appletInterface.isDragInFlight)
        onClicked: {
            const sid = contextMenu.popupStorageId
            if (!sid) return
            if (contextMenu.sharedFavoritesModel) {
                const prefixed = FavoriteId.toPrefixed(sid)
                if (contextMenu.sharedFavoritesModel.isFavorite(prefixed))
                    contextMenu.sharedFavoritesModel.removeFavorite(prefixed)
                else
                    contextMenu.sharedFavoritesModel.addFavorite(prefixed)
            }
        }
        Accessible.name: text
        Accessible.role: Accessible.MenuItem
    }

    PlasmaComponents.MenuSeparator {
        visible: !contextMenu.isMultiSelect
        height: visible ? implicitHeight : 0
    }

    PlasmaComponents.MenuItem {
        icon.name: "pin"
        text: i18nd("dev.xarbit.appgrid", "Pin to Task Manager")
        visible: !contextMenu.isMultiSelect
        height: visible ? implicitHeight : 0
        onClicked: containmentInterface.addLauncher(contextMenu.appletInterface, Kicker.ContainmentInterface.TaskManager, contextMenu.popupDesktopFile)
        Accessible.name: i18nd("dev.xarbit.appgrid", "Pin to Task Manager")
        Accessible.role: Accessible.MenuItem
    }

    PlasmaComponents.MenuItem {
        icon.name: "desktop"
        text: i18nd("dev.xarbit.appgrid", "Add to Desktop")
        visible: !contextMenu.isMultiSelect
        height: visible ? implicitHeight : 0
        onClicked: containmentInterface.addLauncher(contextMenu.appletInterface, Kicker.ContainmentInterface.Desktop, contextMenu.popupDesktopFile)
        Accessible.name: i18nd("dev.xarbit.appgrid", "Add to Desktop")
        Accessible.role: Accessible.MenuItem
    }

    PlasmaComponents.MenuItem {
        icon.name: "document-edit"
        text: i18nd("dev.xarbit.appgrid", "Edit Application")
        visible: !contextMenu.isMultiSelect
        height: visible ? implicitHeight : 0
        onClicked: processRunner.runMenuEditor(contextMenu.popupStorageId)
        Accessible.name: i18nd("dev.xarbit.appgrid", "Edit Application")
        Accessible.role: Accessible.MenuItem
    }

    PlasmaComponents.MenuSeparator {
        visible: !contextMenu.isMultiSelect
        height: visible ? implicitHeight : 0
    }

    PlasmaComponents.MenuItem {
        icon.name: "view-hidden"
        text: i18nd("dev.xarbit.appgrid", "Hide Application")
        visible: !contextMenu.isMultiSelect
        height: visible ? implicitHeight : 0
        onClicked: {
            if (contextMenu.appsModel) {
                contextMenu.appsModel.hideApp(contextMenu.popupIndex)
                Plasmoid.configuration.hiddenApps = contextMenu.appsModel.hiddenApps
            }
        }
        Accessible.name: i18nd("dev.xarbit.appgrid", "Hide Application")
        Accessible.role: Accessible.MenuItem
    }
}
