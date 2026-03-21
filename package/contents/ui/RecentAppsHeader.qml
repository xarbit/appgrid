/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Recently used apps header for the app grid view.
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Column {
    id: recentHeader

    property var appsModel: null
    property real cellWidth: 100
    property real cellHeight: 100
    property real iconSize: Kirigami.Units.iconSizes.huge
    property int currentRecentIndex: -1
    property bool gridHasFocus: false
    property bool favoritesActive: false
    property bool hideBottomLabel: false
    property bool showDividers: true
    property bool showTooltips: true

    signal recentLaunched(string storageId)
    signal contextMenuRequested(string storageId, string desktopFile)
    signal shakeAll()

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        leftPadding: Kirigami.Units.largeSpacing
        text: i18nd("dev.xarbit.appgrid", "Recently Used")
        font.bold: true
        opacity: 0.7
    }

    Flow {
        width: parent.width

        Repeater {
            model: recentHeader.appsModel ? recentHeader.appsModel.recentApps : []
            delegate: Item {
                id: recentDelegate
                required property string modelData
                required property int index
                readonly property var appData: recentHeader.appsModel ? recentHeader.appsModel.getByStorageId(modelData) : ({})
                width: recentHeader.cellWidth
                height: recentHeader.cellHeight
                visible: appData.name !== undefined

                Rectangle {
                    anchors.centerIn: parent
                    width: recentHeader.cellWidth - Kirigami.Units.smallSpacing * 2
                    height: recentHeader.cellHeight - Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                   Kirigami.Theme.highlightColor.g,
                                   Kirigami.Theme.highlightColor.b, 0.2)
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                          Kirigami.Theme.highlightColor.g,
                                          Kirigami.Theme.highlightColor.b, 0.6)
                    visible: recentHeader.currentRecentIndex === recentDelegate.index && recentHeader.gridHasFocus
                }

                AppIconDelegate {
                    id: recentIcon
                    anchors.fill: parent
                    appName: recentDelegate.appData.name || ""
                    appIcon: recentDelegate.appData.iconName || "application-x-executable"
                    appGenericName: recentDelegate.appData.genericName || ""
                    appComment: recentDelegate.appData.comment || ""
                    installSource: recentDelegate.appData.installSource || ""
                    showTooltip: recentHeader.showTooltips
                    isCurrentItem: recentHeader.currentRecentIndex === recentDelegate.index
                    iconSize: recentHeader.iconSize
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton)
                            recentHeader.contextMenuRequested(recentDelegate.modelData, recentDelegate.appData.desktopFile || "")
                        else
                            recentHeader.recentLaunched(recentDelegate.modelData)
                    }
                }

                Connections {
                    target: recentHeader
                    function onShakeAll() { recentIcon.shake() }
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent.width
        opacity: recentHeader.showDividers ? 1 : 0
    }

    PlasmaComponents.Label {
        visible: !recentHeader.hideBottomLabel
        leftPadding: Kirigami.Units.largeSpacing
        text: recentHeader.favoritesActive
              ? i18nd("dev.xarbit.appgrid", "Favorites")
              : i18nd("dev.xarbit.appgrid", "All Apps")
        font.bold: true
        opacity: 0.7
    }

    Item { width: 1; height: Kirigami.Units.smallSpacing }
}
