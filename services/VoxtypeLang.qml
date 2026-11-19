pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "Toml.js" as Toml

// The language Voxtype is set to, for the language entries of its tray menu and the badge on its tray icon
// (sleepybar/widgets/tray/Tray.qml). It is read from Voxtype's own config (whisper.language) because its tray item has no
// overlay icon or menu entry to carry it; `voxtype config set` rewrites that file and restarts Voxtype, so the file is
// watched, not the tray item. Read only: this file is never written. Picking the other language runs `ptt.py lang` from the
// same folder (through DefaultApps), which rewrites the file and restarts Voxtype; the new language shows when the file
// changes. Without that script in the folder the menu has no language rows (`hasScript`).
// `language` is "en", "sr" or "": an array (several languages), a missing key, any other language, a [whisper] table that does
// not parse and a missing file all give "", so the menu and the badge only ever say what is certain. The file is opened while the badge
// is on or Voxtype has a tray item (its menu is there to be opened), and not otherwise.
Singleton {
    id: root

    // `path` and `active` follow the settings; the tests set them to point at their own files
    property string path: Settings.pathVoxtype
    property bool active: Settings.trayVoxtypeLang || root.inTray
    readonly property bool inTray: SystemTray.items.values.some(i => i.id === "voxtype")
    readonly property string language: root.languageOf(root.source)

    property string source: ""

    // the script that switches the language (it toggles between en and sr), in the folder of Voxtype's config
    readonly property string script: root.path.slice(0, root.path.lastIndexOf("/") + 1) + "ptt.py"
    property bool hasScript: false

    // the entry for a language is picked: only the language that is not set, and only when it is known which one is set
    function canPick(code) {
        return root.language !== "" && code !== root.language;
    }

    function pick(code) {
        if (root.canPick(code))
            DefaultApps.run(["python3", "-I", root.script, "lang"]);
    }

    // Only the [whisper] table is cut out and parsed, not the whole file: Voxtype's file holds much that the settings file's strict
    // reader refuses (lists of tables, dotted table names), and a line elsewhere must not hide the language. A header that
    // appears twice, or a table that does not parse, gives "".
    function whisperTable(body) {
        const lines = [];
        let seen = 0;
        let inside = false;
        for (const line of String(body).replace(/\r\n?/g, "\n").split("\n")) {
            if (/^\s*\[\s*whisper\s*\]\s*(#.*)?$/.test(line)) {
                seen++;
                inside = true;
            } else if (/^\s*\[/.test(line)) {
                inside = false;
            } else if (inside) {
                lines.push(line);
            }
        }
        return seen === 1 ? "[whisper]\n" + lines.join("\n") : "";
    }

    function languageOf(body) {
        const table = root.whisperTable(body);
        if (table === "")
            return "";
        const r = Toml.parse(table);
        if (!r.ok)
            return "";
        for (const e of r.sections[r.sections.length - 1].entries) {
            if (e.key !== "language" || typeof e.value !== "string")
                continue;
            const v = e.value.trim().toLowerCase();
            return v === "en" || v === "sr" ? v : "";
        }
        return "";
    }

    FileView {
        // an empty path opens nothing
        path: root.active ? root.path : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.source = text()
        onLoadFailed: root.source = ""
    }

    // whether the script is there, followed while Voxtype has a tray icon; its text is not used
    FileView {
        path: root.inTray ? root.script : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.hasScript = true
        onLoadFailed: root.hasScript = false
    }

    // switching the badge off forgets the old answer, so switching it on again never flashes a stale one
    onActiveChanged: if (!root.active)
        root.source = ""
    onInTrayChanged: if (!root.inTray)
        root.hasScript = false
}
