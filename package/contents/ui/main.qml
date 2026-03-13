import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: kicker

    // Match Kicker's dashboard pattern: icon is fullRepresentation,
    // compactRepresentation is null, preferredRepresentation forces
    // the fullRepresentation to be shown directly in the panel.
    compactRepresentation: null
    fullRepresentation: compactRepresentationComponent
    preferredRepresentation: fullRepresentation

    expandedOnDragHover: false
    hideOnWindowDeactivate: true
    activationTogglesExpanded: false

    Plasmoid.icon: Plasmoid.configuration.useCustomButtonImage
        ? Plasmoid.configuration.customButtonImage
        : Plasmoid.configuration.icon

    property GridWindow gridWindow: null

    Component {
        id: compactRepresentationComponent
        CompactRepresentation {}
    }

    // Super key / external activation
    Connections {
        target: Plasmoid
        function onActivated() {
            kicker.toggleWindow()
        }
    }

    function toggleWindow() {
        if (gridWindow && gridWindow.visible) {
            gridWindow.closeGrid()
        } else {
            if (!gridWindow) {
                gridWindow = gridWindowComponent.createObject(kicker)
            }
            gridWindow.showGrid()
        }
    }

    Component {
        id: gridWindowComponent
        GridWindow {}
    }
}
