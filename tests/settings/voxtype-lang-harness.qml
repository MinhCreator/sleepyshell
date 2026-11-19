// Harness of tests/settings/voxtype-lang.test.sh, copied into the root of the tree under test: drives services/VoxtypeLang.qml
// through a list of steps (a file rewritten in place or atomically, the path moved, the badge switched off and on) and
// prints one line "RESULT <json>" with what `language` said after each. Starts offscreen and quits by itself.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Scope {
    id: h

    readonly property string file: Quickshell.env("VT_FILE")
    readonly property string gone: Quickshell.env("VT_GONE")

    property var results: []
    property int at: -1

    function body(lang) {
        return "[hotkey]\nkey = \"SCROLLLOCK\"\n\n[whisper]\n" + lang + "\n\n[output.notification]\non_recording_start = false\n";
    }

    // each step: { name, run: function }, and the answer is read 600 ms after it
    readonly property var steps: [
        { name: "off", run: () => { VoxtypeLang.path = h.file; VoxtypeLang.active = false; w.atomicWrites = true; w.setText(h.body('language = "sr"')); } },
        { name: "on", run: () => { VoxtypeLang.active = true; } },
        { name: "rewritten-atomic", run: () => { w.atomicWrites = true; w.setText(h.body('language = "en"')); } },
        { name: "rewritten-in-place", run: () => { w.atomicWrites = false; w.setText(h.body('language = "sr"')); } },
        { name: "uppercase", run: () => { w.setText(h.body('language = "EN"')); } },
        { name: "array", run: () => { w.setText(h.body('language = ["en", "sr"]')); } },
        { name: "no-key", run: () => { w.setText(h.body('model = "base"')); } },
        { name: "other-language", run: () => { w.setText(h.body('language = "de"')); } },
        { name: "not-a-string", run: () => { w.setText(h.body('language = 7')); } },
        { name: "broken", run: () => { w.setText("[whisper\nlanguage = = \"en\"\n"); } },
        { name: "valid-again", run: () => { w.setText(h.body('language = "en"')); } },
        // Voxtype's own file holds lists of tables and dotted table names the settings reader refuses; only [whisper] is read
        { name: "lists-of-tables-elsewhere", run: () => { w.setText("[[osd.layers]]\nx = 1\n\n[whisper]\nlanguage = \"sr\"\n\n[[osd.layers]]\ny = 2\n"); } },
        { name: "broken-elsewhere", run: () => { w.setText(h.body('language = "en"') + "[osd\nnonsense = = 1\n"); } },
        { name: "whisper-broken", run: () => { w.setText("[whisper]\nlanguage = = \"en\"\n"); } },
        { name: "whisper-twice", run: () => { w.setText("[whisper]\nlanguage = \"en\"\n\n[whisper]\nmodel = \"base\"\n"); } },
        // the settings reader has no dotted keys, so a language written as `whisper.language = ...` outside the table is not read
        { name: "dotted-key-outside-table", run: () => { w.setText("whisper.language = \"en\"\n"); } },
        { name: "mended", run: () => { w.setText(h.body('language = "en"')); } },
        { name: "missing-file", run: () => { VoxtypeLang.path = h.gone; } },
        { name: "back-to-the-file", run: () => { VoxtypeLang.path = h.file; } },
        { name: "off-again", run: () => { VoxtypeLang.active = false; } },
        { name: "rewritten-while-off", run: () => { w.setText(h.body('language = "sr"')); } },
        { name: "on-after-rewrite", run: () => { VoxtypeLang.active = true; } }
    ]

    FileView {
        id: w
        path: h.file
        printErrors: false
    }

    Timer {
        id: tick
        interval: 600
        repeat: true
        running: true
        onTriggered: {
            if (h.at >= 0)
                h.results.push({ name: h.steps[h.at].name, language: VoxtypeLang.language });
            h.at++;
            if (h.at >= h.steps.length) {
                tick.stop();
                console.log("RESULT " + JSON.stringify(h.results));
                Qt.exit(0);
                return;
            }
            h.steps[h.at].run();
        }
    }
}
