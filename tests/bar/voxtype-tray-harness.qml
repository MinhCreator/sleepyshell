// Harness of tests/bar/voxtype-tray.test.sh, copied into the root of the tree under test and run there with `qs -p` on
// the offscreen platform. It holds the tree's real tray. The test's shell script plays the outside world (a config file
// rewritten, a tray item that registers again) and writes a phase number into the file named by T5_PHASE; the harness
// does what the settings window would do for that phase (previews a staged switch), waits for the bar to settle and prints one
// line "SNAP <phase> <json>" with what each tray item shows. Phase 99 quits.
// Environment: T5_PHASE (the phase file), SLEEPYSHELL_APPS_LOG (where DefaultApps writes what it would have started).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.services
import qs.sleepybar.widgets.tray

Scope {
    id: h
    property int phase: -1

    // the switches each phase stages (undefined: leave them)
    readonly property var staging: ({
            "1": { trayVoxtypeLang: true },
            "4": { trayVoxtypeTint: true },
            "5": { trayVoxtypeLang: false, trayVoxtypeTint: false }
        })

    function find(obj, name) {
        for (const c of obj.children) {
            if (c.objectName === name)
                return c;
            const r = h.find(c, name);
            if (r)
                return r;
        }
        return null;
    }

    function snap() {
        const items = [];
        for (const c of tray.children) {
            if (c.modelData === undefined)
                continue;
            const badge = h.find(c, "voxtypeBadge");
            const icon = h.find(c, "trayIcon");
            const label = badge ? h.find(badge, "voxtypeBadgeText") : null;
            const menu = h.find(c, "trayMenu");
            items.push({ id: c.modelData.id, badge: badge ? badge.visible : null, badgeText: label && badge.visible ? label.text : "",
                tint: icon ? icon.layer.enabled : null,
                menu: menu ? menu.extra.map(e => ({ code: e.code, checked: e.checked, enabled: e.enabled })) : null });
        }
        items.sort((a, b) => a.id < b.id ? -1 : 1);
        console.log("SNAP " + h.phase + " " + JSON.stringify(items));
    }

    function enter(n) {
        if (n === 99) {
            Qt.exit(0);
            return;
        }
        h.phase = n;
        if (n === 6) {
            // picking the language already set runs nothing, picking the other one runs the switch script once
            VoxtypeLang.pick(VoxtypeLang.language);
            VoxtypeLang.pick(VoxtypeLang.language === "sr" ? "en" : "sr");
        }
        const s = h.staging[String(n)];
        if (s) {
            // what the settings window's preview message does in the bar: staged values show at once
            Settings.previewing = true;
            for (const k in s)
                Settings.stage(k, s[k]);
        }
        settle.restart();
    }

    Timer {
        id: settle
        interval: 1500
        onTriggered: h.snap()
    }

    FileView {
        path: Quickshell.env("T5_PHASE")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const n = parseInt(text().trim());
            if (!isNaN(n) && n !== h.phase && n >= 0)
                h.enter(n);
        }
    }

    // never wait forever
    Timer {
        running: true
        interval: 90000
        onTriggered: Qt.exit(1)
    }

    FloatingWindow {
        implicitWidth: 300
        implicitHeight: 60

        Tray {
            id: tray
            bar: null
        }
    }
}
