/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Shared multi-selection state for the grid views (AppGridView and
    CategoryGridView). Each view instantiates one as a child and supplies
    a `sidAt(index)` callback plus a live `gridCount` binding. The state
    object — `sids` (sid → true map) plus `anchor` index — drives the
    Ctrl/Shift+click, Shift+Arrow, and Ctrl+A flows, and is read by
    AppIconDelegate to show the selection halo and ✓ badge.

    Why a map keyed by storageId rather than an Array of indices:
      * Selection survives reorder of the underlying model — KAStats
        favorites can be drag-reordered while items stay selected.
      * O(1) membership for the per-delegate `selected` binding, which
        re-evaluates for every visible item on every selection change.

    Mutation pattern: helpers build a fresh `sids` object and reassign
    `selectionSids` whole, so QML bindings observe the change. In-place
    mutation would not trip the property-changed signal.
*/

import QtQuick

Item {
    id: selection

    // Callable: maps a flat grid index to the app's storageId. Returns ""
    // for invalid indices. Owner must supply — without it the range/select-
    // all operations cannot resolve which apps to mark.
    property var sidAt: function(idx) { return "" }
    // Live total item count for the grid (visible apps). selectAll iterates
    // [0, gridCount); range clamps to it.
    property int gridCount: 0

    // The selection itself: { storageId: true, … }. Reassigned (not mutated)
    // so QML re-evaluates bindings that read it.
    property var selectionSids: ({})
    // Index of the last toggle (Ctrl+click / Space) — pivot for Shift+click
    // and Shift+Arrow range selection. -1 = no anchor.
    property int anchor: -1

    readonly property int selectionCount: {
        var n = 0
        for (var k in selectionSids) if (selectionSids[k]) ++n
        return n
    }

    function contains(sid) {
        return sid && selectionSids[sid] === true
    }

    function sidList() {
        var arr = []
        for (var k in selectionSids) if (selectionSids[k]) arr.push(k)
        return arr
    }

    function toggleAt(idx) {
        const sid = sidAt(idx)
        if (!sid) return
        var copy = Object.assign({}, selectionSids)
        if (copy[sid]) delete copy[sid]
        else copy[sid] = true
        selectionSids = copy
        anchor = idx
    }

    function rangeTo(idx) {
        if (idx < 0 || idx >= gridCount) return
        const a = anchor >= 0 ? anchor : idx
        if (anchor < 0) {
            toggleAt(idx)
            return
        }
        const lo = Math.min(a, idx)
        const hi = Math.max(a, idx)
        var copy = Object.assign({}, selectionSids)
        for (var i = lo; i <= hi; ++i) {
            const sid = sidAt(i)
            if (sid) copy[sid] = true
        }
        selectionSids = copy
    }

    function selectAll(currentIdx) {
        var copy = {}
        for (var i = 0; i < gridCount; ++i) {
            const sid = sidAt(i)
            if (sid) copy[sid] = true
        }
        selectionSids = copy
        if (anchor < 0) anchor = currentIdx >= 0 ? currentIdx : 0
    }

    function clear() {
        if (selectionCount === 0 && anchor < 0) return
        selectionSids = ({})
        anchor = -1
    }
}
