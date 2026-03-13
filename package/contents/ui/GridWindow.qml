import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

Window {
    id: root

    readonly property var appsModel: Plasmoid ? Plasmoid.appsModel : null
    readonly property bool isSearching: searchField.text.length > 0
    readonly property int columns: Math.max(4, Math.min(8, Math.floor(Screen.width / 180)))

    width: Math.min(Screen.width * 0.65, 1200)
    height: Math.min(Screen.height * 0.75, 900)
    x: (Screen.width - width) / 2
    y: (Screen.height - height) / 2

    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Dialog

    function showGrid() {
        searchField.text = ""
        if (appsModel) {
            appsModel.searchText = ""
            appsModel.filterCategory = ""
        }
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2
        visible = true
        requestActivate()
        openAnim.start()
        searchField.forceActiveFocus()
    }

    function closeGrid() {
        closeAnim.start()
    }

    function launchSelected() {
        if (!appsModel) return

        if (isSearching) {
            if (listView.currentIndex >= 0) {
                appsModel.launch(listView.currentIndex)
                closeGrid()
            }
        } else {
            if (gridView.currentIndex >= 0) {
                appsModel.launch(gridView.currentIndex)
                closeGrid()
            }
        }
    }

    onActiveChanged: {
        if (!active && visible) {
            closeGrid()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.closeGrid()
    }

    // Background click to close
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeGrid()
    }

    // Main panel
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: root.width - 20
        height: root.height - 20
        radius: 24
        color: Kirigami.Theme.backgroundColor
        opacity: 0.0
        scale: 1.15
        transformOrigin: Item.Center

        Kirigami.Theme.colorSet: Kirigami.Theme.View
        Kirigami.Theme.inherit: false

        border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                              Kirigami.Theme.textColor.g,
                              Kirigami.Theme.textColor.b, 0.1)
        border.width: 1

        // Absorb clicks inside panel
        MouseArea {
            anchors.fill: parent
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            // Search bar
            PlasmaExtras.SearchField {
                id: searchField
                Layout.fillWidth: true
                onTextChanged: { if (appsModel) appsModel.searchText = text }

                Keys.onReturnPressed: root.launchSelected()
                Keys.onEnterPressed: root.launchSelected()
                Keys.onDownPressed: {
                    if (root.isSearching) {
                        listView.forceActiveFocus()
                        listView.currentIndex = 0
                    }
                }
                Keys.onUpPressed: {
                    if (root.isSearching && listView.currentIndex <= 0) {
                        searchField.forceActiveFocus()
                    }
                }
            }

            // Category bar (hidden during search)
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: categoryRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AsNeeded
                QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOff
                visible: !root.isSearching

                Row {
                    id: categoryRow
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.ToolButton {
                        text: "All"
                        checked: !appsModel || appsModel.filterCategory === ""
                        onClicked: { if (appsModel) appsModel.filterCategory = "" }
                    }

                    Repeater {
                        model: appsModel ? appsModel.categories() : []
                        delegate: PlasmaComponents.ToolButton {
                            required property string modelData
                            text: modelData
                            checked: appsModel && appsModel.filterCategory === modelData
                            onClicked: { if (appsModel) appsModel.filterCategory = modelData }
                        }
                    }
                }
            }

            // Separator
            Kirigami.Separator {
                Layout.fillWidth: true
            }

            // Search results list (visible when searching)
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                visible: root.isSearching

                ListView {
                    id: listView
                    clip: true
                    model: root.isSearching ? appsModel : null
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    highlight: Rectangle {
                        color: Kirigami.Theme.highlightColor
                        radius: Kirigami.Units.cornerRadius
                    }
                    highlightMoveDuration: 0

                    Keys.onReturnPressed: root.launchSelected()
                    Keys.onEnterPressed: root.launchSelected()

                    delegate: QQC2.ItemDelegate {
                        id: listDelegate
                        width: listView.width
                        height: Kirigami.Units.iconSizes.huge + Kirigami.Units.smallSpacing * 2

                        highlighted: listView.currentIndex === model.index

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                implicitWidth: Kirigami.Units.iconSizes.huge
                                implicitHeight: Kirigami.Units.iconSizes.huge
                                source: model.iconName || "application-x-executable"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: model.name || ""
                                    elide: Text.ElideRight
                                    color: listDelegate.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                }

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: model.genericName || ""
                                    elide: Text.ElideRight
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.6
                                    visible: text.length > 0
                                    color: listDelegate.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: listView.currentIndex = model.index
                            onClicked: {
                                if (appsModel) appsModel.launch(model.index)
                                root.closeGrid()
                            }
                        }
                    }
                }
            }

            // App grid (visible when not searching)
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                visible: !root.isSearching

                GridView {
                    id: gridView
                    clip: true
                    cellWidth: Math.floor(width / root.columns)
                    cellHeight: Kirigami.Units.iconSizes.huge + Kirigami.Units.gridUnit * 2 + Kirigami.Units.smallSpacing * 2
                    model: !root.isSearching ? appsModel : null
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Kirigami.Units.iconSizes.huge
                                implicitHeight: Kirigami.Units.iconSizes.huge
                                source: model.iconName || "application-x-executable"
                                active: delegateMouse.containsMouse
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: model.name || ""
                                font: Kirigami.Theme.smallFont
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: delegateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (appsModel) appsModel.launch(model.index)
                                root.closeGrid()
                            }
                        }
                    }
                }
            }
        }
    }

    // Open animation
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: panel; property: "scale"
            from: 1.15; to: 1.0; duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel; property: "opacity"
            from: 0.0; to: 1.0; duration: 120
            easing.type: Easing.OutCubic
        }
    }

    // Close animation
    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: panel; property: "scale"
            from: 1.0; to: 1.12; duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel; property: "opacity"
            from: 1.0; to: 0.0; duration: 120
            easing.type: Easing.InCubic
        }
        onFinished: {
            root.visible = false
            panel.scale = 1.15
            panel.opacity = 0.0
        }
    }
}
