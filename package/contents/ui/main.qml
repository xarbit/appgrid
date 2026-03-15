/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Root plasmoid item: panel icon + custom Window lifecycle.
    Display modes: fullscreen overlay (0) or centered popup (1).
*/

import QtQuick
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: kicker

    compactRepresentation: compactRepresentationComponent
    fullRepresentation: Item {}
    preferredRepresentation: compactRepresentation

    activationTogglesExpanded: false

    Plasmoid.icon: Plasmoid.configuration.useCustomButtonImage
        ? Plasmoid.configuration.customButtonImage
        : Plasmoid.configuration.icon

    property GridWindow gridWindow: null
    property bool gridOpen: false

    Component {
        id: compactRepresentationComponent
        CompactRepresentation {}
    }

    Connections {
        target: Plasmoid
        function onActivated() { kicker.toggleWindow() }
    }

    // Recreate window when display mode changes
    Connections {
        target: Plasmoid.configuration
        function onDisplayModeChanged() { destroyGridWindow() }
    }

    function destroyGridWindow() {
        if (gridWindow) {
            gridWindow.visible = false
            gridWindow.destroy()
            gridWindow = null
        }
        gridOpen = false
    }

    function toggleWindow() {
        if (gridOpen) {
            closeWindow()
        } else {
            openWindow()
        }
    }

    function openWindow() {
        gridOpen = true
        if (!gridWindow)
            gridWindow = gridWindowComponent.createObject(kicker, { appletInterface: kicker })
        gridWindow.showGrid()
    }

    function closeWindow() {
        gridOpen = false
        if (gridWindow)
            gridWindow.closeGrid()
    }

    Component {
        id: gridWindowComponent
        GridWindow {}
    }
}
