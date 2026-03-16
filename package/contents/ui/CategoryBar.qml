/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Horizontal category filter bar with favorites, "All", and dynamic categories.
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

RowLayout {
    id: categoryBar

    property var appsModel: null
    property bool favoritesActive: false
    readonly property bool favoritesFirst: Plasmoid.configuration.startWithFavorites || false

    // Mnemonic map: uppercase letter → { type: "all"|"favorites"|"category", name: string }
    property var mnemonicMap: ({})

    signal favoritesToggled(bool active)

    // Build unique mnemonic assignments for all items.
    // Each item gets the first letter in its name that isn't already taken.
    function rebuildMnemonics() {
        var used = {}
        var map = {}
        var items = []

        // Collect all items: All, categories, Favorites
        items.push({ type: "all", name: i18n("All") })
        var cats = categoryBar.appsModel ? categoryBar.appsModel.categories() : []
        for (var i = 0; i < cats.length; i++)
            items.push({ type: "category", name: cats[i] })
        items.push({ type: "favorites", name: i18n("Favorites") })

        for (var i = 0; i < items.length; i++) {
            var name = items[i].name
            for (var j = 0; j < name.length; j++) {
                var ch = name.charAt(j).toUpperCase()
                if (ch >= 'A' && ch <= 'Z' && !used[ch]) {
                    used[ch] = true
                    map[ch] = items[i]
                    break
                }
            }
        }
        mnemonicMap = map
    }

    // Returns text with '&' inserted before the mnemonic character
    function mnemonicText(name) {
        for (var letter in mnemonicMap) {
            var entry = mnemonicMap[letter]
            if (entry.name === name) {
                var idx = name.toUpperCase().indexOf(letter)
                if (idx >= 0)
                    return name.substring(0, idx) + "&" + name.substring(idx)
            }
        }
        return name
    }

    function selectByMnemonic(key) {
        var letter = String.fromCharCode(key).toUpperCase()
        var entry = mnemonicMap[letter]
        if (!entry)
            return false

        if (entry.type === "all") {
            if (categoryBar.favoritesActive)
                categoryBar.favoritesToggled(false)
            if (categoryBar.appsModel)
                categoryBar.appsModel.filterCategory = ""
            return true
        }
        if (entry.type === "favorites") {
            categoryBar.favoritesToggled(!categoryBar.favoritesActive)
            return true
        }
        if (entry.type === "category") {
            if (categoryBar.favoritesActive)
                categoryBar.favoritesToggled(false)
            if (categoryBar.appsModel)
                categoryBar.appsModel.filterCategory = entry.name
            return true
        }
        return false
    }

    Component.onCompleted: rebuildMnemonics()
    onAppsModelChanged: rebuildMnemonics()
    Connections {
        target: categoryBar.appsModel
        function onCategoriesChanged() { categoryBar.rebuildMnemonics() }
    }

    Layout.fillWidth: true
    spacing: 0

    PlasmaComponents.ToolButton {
        id: favButtonLeft
        visible: categoryBar.favoritesFirst
        icon.name: "folder-favorites"
        checked: categoryBar.favoritesActive
        onClicked: categoryBar.favoritesToggled(!categoryBar.favoritesActive)

        PlasmaComponents.ToolTip.text: i18n("Favorites")
        PlasmaComponents.ToolTip.visible: hovered
        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

        Accessible.name: i18n("Favorites")
        Accessible.role: Accessible.Button
    }

    PlasmaComponents.ToolButton {
        Layout.fillWidth: true
        text: categoryBar.mnemonicText(i18n("All"))
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        checked: !categoryBar.favoritesActive
                 && (!categoryBar.appsModel || categoryBar.appsModel.filterCategory === "")
        onClicked: {
            if (categoryBar.favoritesActive)
                categoryBar.favoritesToggled(false)
            if (categoryBar.appsModel)
                categoryBar.appsModel.filterCategory = ""
        }

        Accessible.name: i18n("All applications")
        Accessible.role: Accessible.Button
    }

    Repeater {
        model: categoryBar.appsModel ? categoryBar.appsModel.categories() : []
        delegate: PlasmaComponents.ToolButton {
            Layout.fillWidth: true
            required property string modelData
            text: categoryBar.mnemonicText(modelData)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            checked: !categoryBar.favoritesActive
                     && categoryBar.appsModel && categoryBar.appsModel.filterCategory === modelData
            onClicked: {
                if (categoryBar.favoritesActive)
                    categoryBar.favoritesToggled(false)
                if (categoryBar.appsModel)
                    categoryBar.appsModel.filterCategory = modelData
            }

            Accessible.name: modelData
            Accessible.role: Accessible.Button
        }
    }

    PlasmaComponents.ToolButton {
        id: favButtonRight
        visible: !categoryBar.favoritesFirst
        icon.name: "folder-favorites"
        checked: categoryBar.favoritesActive
        onClicked: categoryBar.favoritesToggled(!categoryBar.favoritesActive)

        PlasmaComponents.ToolTip.text: i18n("Favorites")
        PlasmaComponents.ToolTip.visible: hovered
        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

        Accessible.name: i18n("Favorites")
        Accessible.role: Accessible.Button
    }
}
