/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Drop handler for the favorites grid. Sits behind the delegates (z
    below them so clicks still reach icons) and handles two drag flavours:

      * Internal: drag.source is the shared DragSource carrying a reference
        to the source delegate via `sourceItem`. We re-order the favorites
        live as the cursor moves, pushing each move onto pendingMoves so
        we can roll back if the user exits without dropping.
      * External: .desktop file drag from Dolphin / elsewhere — added as a
        new favorite at the cursor position.

    On a non-favorites tab, an external file drag triggers
    `gridView.externalFavoriteDragReceived()` so the host can switch tabs
    before the drop lands.
*/

import QtQuick
import org.kde.plasma.plasmoid
import "favoriteid.js" as FavoriteId

DropArea {
    id: reorderArea

    // The owning GridView. We read its dragSource, sharedFavoritesModel,
    // favoritesActive flag, findFavoriteRow() helper, externalFavoriteDragReceived
    // signal, plus the standard GridView geometry/animation properties.
    required property GridView gridView

    // EdgeAutoScroller instance scrolling the same grid; we defer reorder
    // ticks while it's running so the displaced delegates aren't disturbed.
    required property EdgeAutoScroller edgeScroller

    anchors.fill: parent
    z: -1
    // Always alive when the model is available so external file drags can
    // ferry us to the favorites tab. Internal reorder is gated further down
    // on favoritesActive + non-alphabetical mode.
    enabled: gridView.sharedFavoritesModel !== null

    property var pendingMoves: []

    readonly property DragSource _source: gridView.dragSource

    onEntered: drag => {
        pendingMoves = []
        // External drag (file URLs from Dolphin etc.) on a non-favorites
        // tab — switch to favorites so the drop targets the right model.
        // Skip our own drag-out events; those carry text/uri-list too but
        // the user is dragging to leave AppGrid, not to add a favorite.
        if (drag.hasUrls && !(_source && _source.isOwnDrag(drag))
                && (!gridView.favoritesActive
                    || Plasmoid.configuration.sortFavoritesAlphabetically)) {
            gridView.externalFavoriteDragReceived()
        }
    }

    onExited: {
        // Undo every pending move when the cursor leaves without dropping.
        while (pendingMoves.length > 0) {
            const [from, to] = pendingMoves.pop()
            gridView.sharedFavoritesModel.moveRow(to, from)
        }
    }

    onPositionChanged: drag => {
        if (!_source || !_source.isOwnDrag(drag)
                || !_source.sourceItem
                || !gridView.sharedFavoritesModel) {
            return
        }
        // Hold off on reorder while existing animations or auto-scroll are
        // settling. Subsequent positionChanged events will retry.
        if (gridView.move.running || gridView.moveDisplaced.running
                || gridView.flicking || gridView.moving
                || edgeScroller.active) {
            drag.accept(Qt.MoveAction)
            return
        }

        const source = _source.sourceItem
        // Re-resolve the source's current row from the model rather than
        // trusting the cached value — content may have shifted under us
        // during a scroll or external favorites change.
        const liveSourceRow = gridView.findFavoriteRow(source.storageId)
        if (liveSourceRow < 0) return
        source.gridRow = liveSourceRow

        const pos = mapToItem(gridView.contentItem, drag.x, drag.y)
        const target = gridView.indexAt(pos.x, pos.y)
        if (target < 0 || target === liveSourceRow) {
            drag.accept(Qt.MoveAction)
            return
        }

        gridView.sharedFavoritesModel.moveRow(liveSourceRow, target)
        pendingMoves.push([liveSourceRow, target])
        source.gridRow = target
        drag.accept(Qt.MoveAction)
    }

    onDropped: drag => {
        // Internal reorder ended — KAStats persists itself.
        if (_source && _source.isOwnDrag(drag)) {
            pendingMoves = []
            return
        }
        // External drag (e.g. .desktop file from Dolphin) — add as favorite.
        if (!gridView.sharedFavoritesModel || !drag.hasUrls) return
        const pos = mapToItem(gridView.contentItem, drag.x, drag.y)
        let insertAt = gridView.indexAt(pos.x, pos.y)
        for (const url of drag.urls) {
            let id = url.toString()
            // Only accept .desktop drops. KAStats can ingest other URLs but
            // launching a .desktop is the expected favorites use case.
            if (!id.endsWith(".desktop")) continue
            // Strip file:// or path prefix; KAStats's normaliser accepts
            // bare storage IDs (basename) or the prefixed form.
            const slash = id.lastIndexOf("/")
            if (slash >= 0) id = id.substring(slash + 1)
            const prefixed = FavoriteId.toPrefixed(id)
            if (insertAt >= 0) {
                gridView.sharedFavoritesModel.addFavorite(prefixed, insertAt)
                insertAt++
            } else {
                gridView.sharedFavoritesModel.addFavorite(prefixed)
            }
        }
        drag.accept(Qt.CopyAction)
    }
}
