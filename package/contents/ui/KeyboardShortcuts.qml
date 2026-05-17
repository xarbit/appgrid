/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Grid-scoped keyboard shortcuts for AppGridView. The home for any new
    Shortcut declarations that act on the grid; per-key navigation handlers
    (`Keys.on*Pressed`) stay on the GridView itself because they're bound
    to keyboard focus.

    Currently:
      Ctrl+Shift+Arrow  — reorder the highlighted favorite by one cell

    Usage:
        KeyboardShortcuts { gridView: gridView }
*/

import QtQuick
import org.kde.plasma.plasmoid

Item {
    id: shortcuts

    // The owning GridView whose KAStats model the reorder shortcuts mutate.
    // We read its currentIndex, count, effectiveColumns, model,
    // sharedFavoritesModel, and favoritesActive.
    required property GridView gridView

    // --- Favorites reorder (Ctrl+Shift+Arrow) ---

    function reorderable() {
        return gridView.favoritesActive
               && gridView.sharedFavoritesModel
               && gridView.model === gridView.sharedFavoritesModel
               && !Plasmoid.configuration.sortFavoritesAlphabetically
               && gridView.currentIndex >= 0
    }

    function reorderTo(target) {
        if (!reorderable()) return false
        if (target < 0 || target >= gridView.count
                || target === gridView.currentIndex) return false
        gridView.sharedFavoritesModel.moveRow(gridView.currentIndex, target)
        gridView.currentIndex = target
        return true
    }

    Shortcut {
        sequence: "Ctrl+Shift+Right"
        enabled: shortcuts.reorderable() && gridView.currentIndex < gridView.count - 1
        onActivated: shortcuts.reorderTo(gridView.currentIndex + 1)
    }
    Shortcut {
        sequence: "Ctrl+Shift+Left"
        enabled: shortcuts.reorderable() && gridView.currentIndex > 0
        onActivated: shortcuts.reorderTo(gridView.currentIndex - 1)
    }
    Shortcut {
        sequence: "Ctrl+Shift+Down"
        enabled: shortcuts.reorderable()
                 && gridView.currentIndex + gridView.effectiveColumns < gridView.count
        onActivated: shortcuts.reorderTo(gridView.currentIndex + gridView.effectiveColumns)
    }
    Shortcut {
        sequence: "Ctrl+Shift+Up"
        enabled: shortcuts.reorderable()
                 && gridView.currentIndex - gridView.effectiveColumns >= 0
        onActivated: shortcuts.reorderTo(gridView.currentIndex - gridView.effectiveColumns)
    }
}
