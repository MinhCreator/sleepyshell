import QtQuick
import QtQuick.Layouts
import qs.services
import qs.sleepysettings.components

// Settings tab "Right island": which right-island widgets show and in what order, update checks.
// Notifications have their own tab (NotificationsTab.qml), and the wallpaper folder is in the Theme
// tab.
TabPage {
    id: tab
    key: "widgets"
    label: "Right island"
    icon: 0xF10AB
    group: "widgets"

    // one line per widget: grip (drag to reorder), name, shown
    Section {
        title: "Widgets"
        // the keybind overlay's indicator is one of these: its reporter in hyprland.lua, offered with Set up
        fileIds: ["keyreport"]

        OrderList {
            orderKey: "rightOrder"
            hiddenKey: "rightHidden"
            labels: Settings.widgetLabels
            query: tab.query
            noun: "widget"
        }
        ChoiceRow {
            label: "Dropdown fit"
            key: "dropdownFit"
            info: "Extend: the island widens so a widget's dropdown hangs flush under it, as one shape. Float: the island stays as it is and the dropdown is a separate card under it."
            tags: "dropdown panel island extend float card shape"
            options: [["extend", "Extend"], ["float", "Float"]].map(p => ({
                        value: p[0],
                        label: p[1]
                    }))
        }
    }

    Section {
        title: "Voxtype"

        SwitchRow {
            label: "Language badge"
            key: "trayVoxtypeLang"
            info: "Shows EN or SR on Voxtype's tray icon, as set in Voxtype's own config file (the Config tab says which one). Nothing shows if the language is not one of those or the file can't be read. Voxtype's tray menu lists the language whether this is on or off."
            tags: "voxtype voice dictation language english serbian badge tray"
        }
        SwitchRow {
            label: "Tint the icon"
            key: "trayVoxtypeTint"
            info: "Colours Voxtype's tray icon to match the bar's other icons."
            tags: "voxtype voice dictation colour color tint tray icon"
        }
    }

    AdvancedSection {
        NumberRow {
            label: "Update check interval"
            key: "updateMinutes"
            requires: ["pacman", "paru", "fakeroot"]
            suffix: " min"
            info: "How often the Package updates widget looks for package updates."
            tags: "pacman packages updates check every"
        }
        NumberRow {
            label: "Island padding"
            key: "rightPadding"
            suffix: " px"
            info: "Space between the right island's edges and its widgets."
            tags: "padding space margin island edge"
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
