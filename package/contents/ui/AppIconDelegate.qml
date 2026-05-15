/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Reusable app icon delegate with configurable hover animation.
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Item {
    id: root

    property string appName: ""
    property string appIcon: "application-x-executable"
    property string appGenericName: ""
    property string appComment: ""
    property string installSource: ""
    property bool showTooltip: false
    property bool isCurrentItem: false
    property bool isNew: false
    property bool hideLabel: false
    property real iconSize: Kirigami.Units.iconSizes.huge
    // Identity used by the favorites drag controller. Set externally;
    // empty disables dragging.
    property string storageId: ""
    property int gridRow: -1
    // External proxy that carries the grab image; set when dragging should
    // be enabled in this view (favorites tab only).
    property Item dragProxy: null
    signal clicked(var mouse)

    // Visual icon override for shuffle animation (set externally by the grid)
    property string displayIcon: ""

    // Emitted when shuffle animation wants to swap with another icon
    signal shuffleRequested()

    // 0=None, 1=Shake, 2=Grow, 3=Bounce, 4=Spin, 5=Shuffle
    readonly property int hoverAnimation: Plasmoid.configuration.hoverAnimation
    readonly property var iconAnimFiles: [
        "",                          // 0=None
        "iconanims/ShakeAnim.qml",   // 1
        "iconanims/GrowAnim.qml",    // 2
        "iconanims/BounceAnim.qml",  // 3
        "iconanims/SpinAnim.qml"     // 4
        // 5=Shuffle handled separately via signal
    ]

    Loader {
        id: iconAnimLoader
        source: hoverAnimation > 0 && hoverAnimation < iconAnimFiles.length ? iconAnimFiles[hoverAnimation] : ""
        onLoaded: {
            item.target = delegateIcon
            // GrowAnim supports persistent hover via a hovered property
            if (item.hasOwnProperty("hovered"))
                item.hovered = Qt.binding(function() { return delegateMouse.containsMouse })
        }
    }

    function shake() {
        playAnimation()
    }

    function playAnimation() {
        if (Kirigami.Units.longDuration === 0) return
        if (hoverAnimation === 5) {
            shuffleRequested()
        } else if (iconAnimLoader.item) {
            iconAnimLoader.item.start()
        }
    }

    // Highlight background shown while this delegate is being dragged.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.highlightColor
        opacity: 0.25
        visible: pointerDrag.active || touchDrag.active
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.alignment: (root.hideLabel ? Qt.AlignVCenter : Qt.AlignTop) | Qt.AlignHCenter
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize

            Kirigami.Icon {
                id: delegateIcon
                anchors.fill: parent
                source: root.displayIcon || root.appIcon || "application-x-executable"
                active: delegateMouse.containsMouse || root.isCurrentItem
                transformOrigin: Item.Center
            }

            // "New" badge dot
            Rectangle {
                visible: root.isNew
                width: Kirigami.Units.smallSpacing * 3
                height: width
                radius: width / 2
                color: Kirigami.Theme.positiveTextColor
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -Kirigami.Units.smallSpacing
                anchors.rightMargin: -Kirigami.Units.smallSpacing

                Accessible.ignored: true
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hideLabel
            verticalAlignment: Text.AlignTop
            text: root.appName
            font: Kirigami.Theme.defaultFont
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Tooltip with app name, description, and install source
    readonly property string tooltipText: {
        var parts = []
        if (root.appName)
            parts.push(root.appName)
        if (root.appComment)
            parts.push(root.appComment)
        else if (root.appGenericName && root.appGenericName !== root.appName)
            parts.push(root.appGenericName)
        if (root.installSource.length > 0)
            parts.push("Source: " + root.installSource)
        return parts.join("\n")
    }

    PlasmaComponents.ToolTip.text: root.tooltipText
    PlasmaComponents.ToolTip.visible: root.showTooltip && delegateMouse.containsMouse
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    MouseArea {
        id: delegateMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.playAnimation()

        onClicked: function(mouse) {
            root.clicked(mouse)
        }

        onPressAndHold: function(mouse) {
            root.clicked({ button: Qt.RightButton, x: mouse.x, y: mouse.y })
        }

        Accessible.name: root.appName + (root.isNew ? ", " + i18nd("dev.xarbit.appgrid", "new") : "")
        Accessible.role: Accessible.Button
        Accessible.description: root.appGenericName
        Accessible.focusable: true
    }

    // -- Drag handler for favorites reordering --
    // Activates a shared external proxy carrying the grabbed icon image.
    // Only enabled when `dragProxy` and `storageId` are set, which the
    // favorites view does. Position-based reorder happens in the surrounding
    // DropArea (see AppGridView).
    function _beginDrag(handler) {
        if (!root.dragProxy) return
        if (!handler.active) {
            root.dragProxy.Drag.active = false
            root.dragProxy.Drag.imageSource = ""
            root.dragProxy.sourceItem = null
            return
        }
        delegateIcon.grabToImage(function(result) {
            if (!handler.active) return
            root.dragProxy.sourceItem = root
            root.dragProxy.Drag.imageSource = result.url
            root.dragProxy.Drag.mimeData = { "text/x-appgrid-storage-id": root.storageId }
            root.dragProxy.Drag.active = true
        })
    }

    DragHandler {
        id: pointerDrag
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        enabled: root.dragProxy !== null && root.storageId.length > 0
        target: null
        onActiveChanged: root._beginDrag(this)
    }

    DragHandler {
        id: touchDrag
        acceptedDevices: PointerDevice.TouchScreen
        enabled: pointerDrag.enabled
        target: null
        // Both axes free — favorites grid reorders in 2D, unlike the list
        // views in upstream Kickoff that only need a single axis.
        onActiveChanged: root._beginDrag(this)
    }

    // Lift delegate above siblings while dragging
    z: (pointerDrag.active || touchDrag.active) ? 10 : 0
}
