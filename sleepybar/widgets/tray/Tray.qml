import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services
import "../../../services/LocalImage.js" as LocalImage

// StatusNotifier tray. Quickshell registers org.kde.StatusNotifierWatcher itself,
// so the gdbus wait in autostart.lua keeps working. Left: activate, middle: secondary,
// right: the item's menu, drawn themed by TrayMenu.
RowLayout {
    id: root
    required property var bar
    spacing: 4
    // `shown` is what the right island's Loader follows (Sleepybar.qml), so an empty tray takes no slot
    readonly property bool shown: SystemTray.items.values.length > 0
    visible: shown

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: item
            required property SystemTrayItem modelData
            // matched by id: Voxtype's item is registered again when its language is changed (it restarts), so the
            // delegate is rebuilt with a new item and only the id stays the same
            readonly property bool isVoxtype: modelData.id === "voxtype"
            implicitWidth: 24
            implicitHeight: Theme.buttonHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: m => {
                if (m.button === Qt.LeftButton && !modelData.onlyMenu)
                    modelData.activate();
                else if (m.button === Qt.MiddleButton)
                    modelData.secondaryActivate();
                else if (modelData.hasMenu || menu.extra.length > 0)
                    menu.toggle();
            }
            onWheel: w => {
                if (w.angleDelta.y !== 0)
                    modelData.scroll(w.angleDelta.y, false);
            }

            // above its neighbours while lifted, so the shadow is not covered
            z: surface.z

            // same inset geometry as the right island's BarButtons; only the highlight lifts, the
            // icon stays at scale 1 so it stays sharp; the holder keeps the
            // lifted highlight (z 1) under the icon
            Item {
                anchors.fill: parent

            Item {
                id: surface
                anchors.fill: parent

                Lift {
                    pointer: item
                    level: item.containsMouse ? 1 : 0
                    shape: trayHl
                    radius: trayHl.radius
                }

                Highlight {
                    id: trayHl
                    anchors.fill: parent
                    anchors.topMargin: Theme.insetPad
                    glued: false
                    radius: Theme.insetRadius
                    color: item.containsMouse ? Theme.hoverBg : "transparent"
                }
            }
            }

            IconImage {
                id: trayImg
                objectName: "trayIcon"
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Theme.insetPad / 2
                implicitSize: Theme.barIconSize
                asynchronous: true
                source: root.iconSource(item.modelData.icon)
                // a plain tint, nothing about recording: the OSD already shows that. With the tint on, the icon is only
                // the shape (layer, hidden) for the flat colour below.
                layer.enabled: item.isVoxtype && Settings.trayVoxtypeTint
                visible: !layer.enabled
            }

            // Theme.fg through the icon's outline: a colorization keeps the icon's own brightness, which left a grey
            // icon grey; this is the exact colour of the other tray and bar icons
            MultiEffect {
                anchors.fill: trayImg
                visible: trayImg.layer.enabled
                source: tintFill
                maskEnabled: true
                maskSource: trayImg
            }
            Rectangle {
                id: tintFill
                visible: false
                layer.enabled: true
                width: trayImg.width
                height: trayImg.height
                color: Theme.fg
            }

            // the language, from Voxtype's config (VoxtypeLang): its tray item carries no overlay icon
            Rectangle {
                objectName: "voxtypeBadge"
                visible: item.isVoxtype && Settings.trayVoxtypeLang && VoxtypeLang.language !== ""
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.insetPad / 2
                // sized to the letters' ink, not the text line (which adds room for descenders the capitals never
                // use): one pixel of fill between the letters and the outline
                width: badgeInk.tightBoundingRect.width + 2 * (border.width + 1)
                height: badgeInk.tightBoundingRect.height + 2 * (border.width + 1)
                radius: Theme.radiusXs
                color: Theme.fg
                // dark against the light icon behind the pill, so the pill reads as its own shape
                border.width: 1
                border.color: Theme.surface

                TextMetrics {
                    id: badgeInk
                    font: badgeText.font
                    text: badgeText.text
                }

                Text {
                    id: badgeText
                    objectName: "voxtypeBadgeText"
                    // the ink's top-left corner (relative to the baseline) goes to the inner corner of the pill
                    x: parent.border.width + 1 - badgeInk.tightBoundingRect.x
                    y: parent.border.width + 1 - badgeText.baselineOffset - badgeInk.tightBoundingRect.y
                    text: VoxtypeLang.language.toUpperCase()
                    font.family: Theme.font
                    // the dropdown text size minus a step: it stays legible at the smallest setting, where half the icon would not
                    font.pixelSize: Theme.fontSize - 3
                    font.weight: Font.Medium
                    color: Theme.surface
                }
            }

            TrayMenu {
                id: menu
                objectName: "trayMenu"
                hideLabels: item.isVoxtype ? ["Language", "Cancel"] : []
                handle: item.modelData.menu
                anchorItem: item
                bar: root.bar
                // Voxtype's own menu has no language entries; these show the language and pick the other one, whether or
                // not the badge is on (the badge switch is only the pill). Without the switch script, or while the language
                // cannot be read, there are none: a row that does nothing must not look live.
                extra: item.isVoxtype && VoxtypeLang.hasScript && VoxtypeLang.language !== "" ? [
                    { text: "English (EN)", code: "en", checked: VoxtypeLang.language === "en", enabled: VoxtypeLang.canPick("en") },
                    { text: "Serbian (SR)", code: "sr", checked: VoxtypeLang.language === "sr", enabled: VoxtypeLang.canPick("sr") }
                ] : []
                onExtraPicked: i => VoxtypeLang.pick(extra[i].code)
            }
        }
    }

    // A tray icon as a local source only (LocalImage.js). Quickshell gives "image://icon/<name>",
    // "image://icon/<name>?path=<dir>" (the app's own icon folder) or its pixmap provider; for a
    // folder the theme icon wins, else the file in that folder when the folder is an absolute path.
    function iconSource(icon) {
        const s = String(icon ?? "");
        if (!s.includes("?path="))
            return LocalImage.only(s);
        const [name, path] = s.split("?path=");
        const file = name.slice(name.lastIndexOf("/") + 1);
        return Quickshell.iconPath(file, true) || LocalImage.fileUrl(path.replace(/\/+$/, "") + "/" + file);
    }
}
