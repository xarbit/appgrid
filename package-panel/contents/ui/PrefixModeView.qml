/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    View for prefix mode commands: help, terminal, shell command, file browser.
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Item {
    id: prefixView

    property string mode: ""       // "help", "terminal", "command", "files", "info", "hidden"
    property string argument: ""   // text after the prefix
    property Item searchField: null

    signal fileOpened()
    signal directoryNavigated(string path)

    function focusFileList() {
        fileList.forceActiveFocus()
    }

    function activateFileCurrent() {
        fileList.activateCurrent()
    }

    // -- Help mode --
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 2
        visible: prefixView.mode === "help"
        spacing: 0

        // Header
        PlasmaComponents.Label {
            text: i18nd("dev.xarbit.appgrid", "Quick Commands")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            Layout.bottomMargin: Kirigami.Units.largeSpacing * 2
        }

        // Command list with sections
        Repeater {
            model: [
                { section: i18nd("dev.xarbit.appgrid", "Run") },
                { prefix: "t:", icon: "utilities-terminal", title: i18nd("dev.xarbit.appgrid", "Terminal"), example: "t:htop" },
                { prefix: ":",  icon: "system-run",         title: i18nd("dev.xarbit.appgrid", "Run Command"), example: ":xdg-open ." },

                { section: i18nd("dev.xarbit.appgrid", "Browse") },
                { prefix: "/",  icon: "folder-open",        title: i18nd("dev.xarbit.appgrid", "Browse Files"), example: "/usr/bin" },
                { prefix: "~/", icon: "folder-home",        title: i18nd("dev.xarbit.appgrid", "Browse Home"), example: "~/Documents" },

                { section: i18nd("dev.xarbit.appgrid", "Tools") },
                { prefix: "i:", icon: "documentinfo",       title: i18nd("dev.xarbit.appgrid", "System Info"), example: "i:" },
                { prefix: "h:", icon: "view-hidden",        title: i18nd("dev.xarbit.appgrid", "Hidden Apps"), example: "h:" },
                { prefix: "?",  icon: "help-hint",          title: i18nd("dev.xarbit.appgrid", "This Help"), example: "" }
            ]

            delegate: Item {
                Layout.fillWidth: true
                implicitHeight: modelData.section
                    ? sectionLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
                    : commandRow.implicitHeight + Kirigami.Units.largeSpacing * 2

                // Section header
                PlasmaComponents.Label {
                    id: sectionLabel
                    visible: !!modelData.section
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                        bottomMargin: Kirigami.Units.smallSpacing
                    }
                    text: modelData.section || ""
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.bold: true
                    opacity: 0.4
                    font.capitalization: Font.AllUppercase
                }

                // Command row
                RowLayout {
                    id: commandRow
                    visible: !modelData.section
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        source: modelData.icon || ""
                        opacity: 0.6
                    }

                    // Prefix badge
                    Rectangle {
                        implicitWidth: Math.max(Kirigami.Units.gridUnit * 2.5,
                                                prefixText.implicitWidth + Kirigami.Units.largeSpacing)
                        implicitHeight: prefixText.implicitHeight + Kirigami.Units.smallSpacing * 2
                        radius: Kirigami.Units.cornerRadius
                        color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                       Kirigami.Theme.highlightColor.g,
                                       Kirigami.Theme.highlightColor.b, 0.15)

                        PlasmaComponents.Label {
                            id: prefixText
                            anchors.centerIn: parent
                            text: modelData.prefix || ""
                            font.family: "monospace"
                            font.bold: true
                        }
                    }

                    PlasmaComponents.Label {
                        text: modelData.title || ""
                        Layout.fillWidth: true
                    }

                    // Example
                    PlasmaComponents.Label {
                        visible: (modelData.example || "").length > 0
                        text: modelData.example || ""
                        font.family: "monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.4
                    }
                }

                // Bottom separator (commands only)
                Rectangle {
                    visible: !modelData.section
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                   Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.06)
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Keyboard tip
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18nd("dev.xarbit.appgrid", "Alt+1\u2009\u2013\u2009Alt+9 launches search results instantly")
            font: Kirigami.Theme.smallFont
            opacity: 0.35
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // -- Terminal / Command hint --
    ColumnLayout {
        anchors.centerIn: parent
        visible: prefixView.mode === "terminal" || prefixView.mode === "command"
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            source: prefixView.mode === "terminal" ? "utilities-terminal" : "system-run"
            opacity: 0.5
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (prefixView.argument.trim().length === 0)
                    return prefixView.mode === "terminal"
                        ? i18nd("dev.xarbit.appgrid", "Type a command to run in terminal")
                        : i18nd("dev.xarbit.appgrid", "Type a command to execute")
                return prefixView.mode === "terminal"
                    ? i18nd("dev.xarbit.appgrid", "Press Enter to run in terminal")
                    : i18nd("dev.xarbit.appgrid", "Press Enter to execute")
            }
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            opacity: 0.7
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            visible: prefixView.argument.trim().length > 0
            text: prefixView.argument.trim()
            font.family: "monospace"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            opacity: 0.9
        }
    }

    // -- System info --
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 2
        visible: prefixView.mode === "info"
        spacing: 0

        property var sysInfo: prefixView.mode === "info" ? Plasmoid.systemInfo() : ({})

        PlasmaComponents.Label {
            text: i18nd("dev.xarbit.appgrid", "System Information")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            Layout.bottomMargin: Kirigami.Units.largeSpacing * 2
        }

        Repeater {
            model: [
                { label: "AppGrid",  value: parent.sysInfo.appgridVersion || "" },
                { label: "Variant",  value: parent.sysInfo.variant || "" },
                { label: "Session",  value: parent.sysInfo.sessionType || "" },
                { label: "Plasma",   value: parent.sysInfo.plasmaVersion || "" },
                { label: "KF",       value: parent.sysInfo.kfVersion || "" },
                { label: "Qt",       value: parent.sysInfo.qtVersion || "" },
                { label: "OS",       value: parent.sysInfo.os || "" },
                { label: "Screens",  value: parent.sysInfo.screens || "" }
            ]

            delegate: Item {
                Layout.fillWidth: true
                implicitHeight: infoRow.implicitHeight + Kirigami.Units.largeSpacing * 2

                RowLayout {
                    id: infoRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Kirigami.Units.largeSpacing

                    PlasmaComponents.Label {
                        text: modelData.label
                        font.bold: true
                        opacity: 0.6
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                    }

                    PlasmaComponents.Label {
                        text: modelData.value
                        font.family: "monospace"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                   Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.06)
                }
            }
        }

        Item { Layout.fillHeight: true }

        PlasmaComponents.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            icon.name: copyTimer.running ? "dialog-ok-apply" : "edit-copy"
            text: copyTimer.running
                ? i18nd("dev.xarbit.appgrid", "Copied!")
                : i18nd("dev.xarbit.appgrid", "Copy to Clipboard")
            onClicked: {
                var info = parent.sysInfo
                var lines = [
                    "AppGrid: " + (info.appgridVersion || ""),
                    "Variant: " + (info.variant || ""),
                    "Session: " + (info.sessionType || ""),
                    "Plasma: " + (info.plasmaVersion || ""),
                    "KF: " + (info.kfVersion || ""),
                    "Qt: " + (info.qtVersion || ""),
                    "OS: " + (info.os || ""),
                    "Screens: " + (info.screens || "")
                ]
                infoClipboard.text = lines.join("\n")
                infoClipboard.selectAll()
                infoClipboard.copy()
                copyTimer.start()
            }

            Timer {
                id: copyTimer
                interval: 2000
            }

            TextEdit {
                id: infoClipboard
                visible: false
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: i18nd("dev.xarbit.appgrid", "Include this info when reporting issues on GitHub")
            font: Kirigami.Theme.smallFont
            opacity: 0.35
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // -- Hidden apps manager --
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 2
        visible: prefixView.mode === "hidden"
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.largeSpacing * 2

            PlasmaComponents.Label {
                text: i18nd("dev.xarbit.appgrid", "Hidden Applications")
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                Layout.fillWidth: true
            }

            PlasmaComponents.Button {
                visible: Plasmoid.appsModel.hiddenApps.length > 0
                icon.name: "edit-undo"
                text: i18nd("dev.xarbit.appgrid", "Unhide All")
                onClicked: {
                    Plasmoid.appsModel.hiddenApps = []
                    Plasmoid.configuration.hiddenApps = []
                }
            }
        }

        // Empty state — centered in the remaining space
        Item {
            visible: Plasmoid.appsModel.hiddenApps.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Kirigami.Units.iconSizes.huge
                    implicitHeight: Kirigami.Units.iconSizes.huge
                    source: "view-visible"
                    opacity: 0.3
                }

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: i18nd("dev.xarbit.appgrid", "No hidden applications")
                    opacity: 0.5
                }

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: i18nd("dev.xarbit.appgrid", "Right-click any app in the grid to hide it")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.35
                }
            }
        }

        // Hidden apps list
        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Plasmoid.appsModel.hiddenApps.length > 0
            PlasmaComponents.ScrollBar.horizontal.policy: PlasmaComponents.ScrollBar.AlwaysOff

            ListView {
                id: hiddenList
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Plasmoid.appsModel.hiddenApps

                delegate: PlasmaComponents.ItemDelegate {
                    id: hiddenDelegate
                    width: hiddenList.width
                    height: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2

                    property var appInfo: Plasmoid.appsModel.getByStorageId(modelData) || ({})

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            source: hiddenDelegate.appInfo.iconName || "application-x-executable"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: hiddenDelegate.appInfo.name || modelData
                                elide: Text.ElideRight
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: hiddenDelegate.appInfo.genericName || ""
                                font: Kirigami.Theme.smallFont
                                opacity: 0.5
                                elide: Text.ElideRight
                            }
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: "view-visible"
                            PlasmaComponents.ToolTip.text: i18nd("dev.xarbit.appgrid", "Unhide")
                            PlasmaComponents.ToolTip.visible: hovered
                            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: {
                                Plasmoid.appsModel.unhideApp(modelData)
                                Plasmoid.configuration.hiddenApps = Plasmoid.appsModel.hiddenApps
                            }
                        }
                    }
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: Plasmoid.appsModel.hiddenApps.length > 0
            text: i18nd("dev.xarbit.appgrid", "%1 hidden application(s)", Plasmoid.appsModel.hiddenApps.length)
            font: Kirigami.Theme.smallFont
            opacity: 0.35
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // -- File browser --
    PlasmaComponents.ScrollView {
        anchors.fill: parent
        visible: prefixView.mode === "files"
        PlasmaComponents.ScrollBar.horizontal.policy: PlasmaComponents.ScrollBar.AlwaysOff

        ListView {
            id: fileList
            clip: true
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            highlight: Rectangle {
                color: Kirigami.Theme.highlightColor
                radius: Kirigami.Units.cornerRadius
            }

            model: ListModel { id: fileModel }

            property string currentPath: ""

            function refresh() {
                var items = Plasmoid.listDirectory(prefixView.argument)
                fileModel.clear()
                for (var i = 0; i < items.length; i++)
                    fileModel.append(items[i])
                currentIndex = fileModel.count > 0 ? 0 : -1
            }

            Keys.onReturnPressed: activateCurrent()
            Keys.onEnterPressed: activateCurrent()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Backspace && prefixView.searchField) {
                    prefixView.searchField.forceActiveFocus()
                    prefixView.searchField.text = prefixView.searchField.text.slice(0, -1)
                    event.accepted = true
                } else if (event.text.length > 0 && !event.modifiers && prefixView.searchField) {
                    prefixView.searchField.forceActiveFocus()
                    prefixView.searchField.text += event.text
                    event.accepted = true
                }
            }

            function activateCurrent() {
                if (currentIndex < 0 || currentIndex >= fileModel.count)
                    return
                var item = fileModel.get(currentIndex)
                if (item.isDir) {
                    prefixView.directoryNavigated(item.path + "/")
                } else {
                    Plasmoid.openFile(item.path)
                    prefixView.fileOpened()
                }
            }

            delegate: PlasmaComponents.ItemDelegate {
                id: fileDelegate
                width: fileList.width
                height: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
                highlighted: fileList.currentIndex === model.index

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                        source: model.icon || "application-x-generic"
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: model.name || ""
                        elide: Text.ElideRight
                        color: fileDelegate.highlighted
                               ? Kirigami.Theme.highlightedTextColor
                               : Kirigami.Theme.textColor
                    }

                    PlasmaComponents.Label {
                        visible: model.isDir
                        text: ">"
                        opacity: 0.4
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: fileList.currentIndex = model.index
                    onClicked: fileList.activateCurrent()
                }
            }

            Connections {
                target: prefixView
                function onArgumentChanged() {
                    if (prefixView.mode === "files")
                        fileList.refresh()
                }
                function onModeChanged() {
                    if (prefixView.mode === "files")
                        fileList.refresh()
                }
            }
        }
    }
}
