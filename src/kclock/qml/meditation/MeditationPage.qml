import QtQuick
import QtCore
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root
    objectName: "Meditation"
    title: i18n("Meditate")

    property string phase: "idle" // idle | preparing | running
    property bool paused: false
    property double phaseEnd: 0
    property double sessionStart: 0
    property double sessionEnd: 0
    property double pausedAt: 0
    property double msLeft: 0
    property int remaining: 0
    property int sessionMinutes: 20

    // the digits fade out and the enso fades in over the whole sit
    readonly property real fadeSeconds: sessionMinutes * 60
    property real fade: 0       // 0..1 while sitting
    property bool done: false   // the sit ran to the end: the enso stays visible
    readonly property real ensoOpacity: phase === "running" ? fade : (phase === "idle" && done ? 1 : 0)

    property bool wakeSent: false

    // used by the page-switch animation in Main.qml
    property real yTranslate: 0

    // remembers prep time and session length between runs
    Settings {
        category: "Meditation"
        property alias prep: prepBox.value
        property alias length: root.sessionMinutes
    }

    function fmt(s) {
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function start() {
        fade = 0;
        done = false;
        paused = false;
        wakeSent = false;
        phase = "preparing";
        remaining = prepBox.value;
        phaseEnd = Date.now() + prepBox.value * 1000;
        tick.start();
    }

    // freeze the countdown and the enso where they are
    function pause() {
        const now = Date.now();
        tick.stop();
        pausedAt = now;
        msLeft = Math.max(0, (phase === "preparing" ? phaseEnd : sessionEnd) - now);
        paused = true;
    }

    // carry on from the same point
    function resume() {
        const now = Date.now();
        if (phase === "preparing") {
            phaseEnd = now + msLeft;
        } else {
            sessionEnd = now + msLeft;
            sessionStart += now - pausedAt;
        }
        wakeSent = false;
        paused = false;
        tick.start();
    }

    // back to the start screen, and silence
    function reset() {
        tick.stop();
        startBell.stop();
        endBell.stop();
        wake.stop();
        phase = "idle";
        paused = false;
        done = false;
        fade = 0;
    }

    // session ran to the end: the enso stays, 2 closing strikes
    function finish() {
        tick.stop();
        phase = "idle";
        paused = false;
        done = true;
        endBell.play();
    }

    // follows the system default audio output (e.g. a newly connected speaker)
    MediaDevices { id: mediaDevices }

    // the opening strikes and the closing strikes are ready-made sounds, exactly 6 s apart
    MediaPlayer {
        id: startBell
        source: Qt.resolvedUrl("bell_start.flac")
        audioOutput: AudioOutput { device: mediaDevices.defaultAudioOutput }
    }

    MediaPlayer {
        id: endBell
        source: Qt.resolvedUrl("bell_end.flac")
        audioOutput: AudioOutput { device: mediaDevices.defaultAudioOutput }
    }

    // a near-silent sound wakes the audio output 1.5 s before the first strike
    MediaPlayer {
        id: wake
        source: Qt.resolvedUrl("wake.wav")
        audioOutput: AudioOutput { device: mediaDevices.defaultAudioOutput }
    }

    // drives the cross-fade while sitting
    Timer {
        interval: 100
        repeat: true
        running: root.phase === "running" && !root.paused
        onTriggered: root.fade = Math.min(1, (Date.now() - root.sessionStart) / (root.fadeSeconds * 1000))
    }

    Timer {
        id: tick
        interval: 250
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (root.phase === "preparing") {
                root.remaining = Math.max(0, Math.ceil((root.phaseEnd - now) / 1000));
                if (!root.wakeSent && now >= root.phaseEnd - 1500) {
                    root.wakeSent = true;
                    wake.stop();
                    wake.play();
                }
                if (now >= root.phaseEnd) {
                    root.phase = "running";
                    root.wakeSent = false;
                    startBell.play();
                    root.sessionStart = now;
                    root.sessionEnd = now + root.sessionMinutes * 60000;
                    root.remaining = root.sessionMinutes * 60;
                }
            } else if (root.phase === "running") {
                root.remaining = Math.max(0, Math.ceil((root.sessionEnd - now) / 1000));
                if (!root.wakeSent && now >= root.sessionEnd - 1500) {
                    root.wakeSent = true;
                    wake.stop();
                    wake.play();
                }
                if (now >= root.sessionEnd) {
                    root.finish();
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        transform: Translate { y: root.yTranslate }
        spacing: Kirigami.Units.largeSpacing

        Item {
            id: ensoBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 7
            readonly property real diameter: Math.min(width, height)

            // the enso, fading in while you sit
            Kirigami.Icon {
                anchors.centerIn: parent
                width: ensoBox.diameter
                height: ensoBox.diameter
                source: Qt.resolvedUrl("enso.png")
                isMask: true
                color: Kirigami.Theme.textColor
                smooth: true
                opacity: root.ensoOpacity
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            // the countdown, in the middle of the circle, fading out while you sit
            Controls.Label {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                font.features: { "tnum": 1 }
                font.pixelSize: Math.round(ensoBox.diameter * 0.19)
                font.weight: Font.ExtraLight
                opacity: 1 - root.ensoOpacity
                Behavior on opacity { NumberAnimation { duration: 400 } }
                text: root.phase === "idle" ? root.fmt(root.sessionMinutes * 60) : root.fmt(root.remaining)
            }
        }

        Controls.Label {
            Layout.alignment: Qt.AlignHCenter
            opacity: root.phase === "preparing" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            text: i18n("Get ready…")
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            enabled: root.phase === "idle"
            opacity: root.phase === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }

            Repeater {
                model: [10, 15, 20, 25, 30, 35]
                Controls.Button {
                    Layout.fillWidth: true
                    text: i18n("%1 min", modelData)
                    onClicked: {
                        root.sessionMinutes = modelData;
                        root.done = false;
                    }
                }
            }
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            enabled: root.phase === "idle"
            opacity: root.phase === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }

            Controls.Label { text: i18n("Prep time (s)") }
            Controls.SpinBox { id: prepBox; from: 0; to: 120; value: 10 }
        }

        Controls.Button {
            Layout.alignment: Qt.AlignHCenter
            icon.name: (root.phase === "idle" || root.paused) ? "media-playback-start" : "media-playback-pause"
            text: root.phase === "idle" ? i18n("Let’s sit!") : (root.paused ? i18n("Resume") : i18n("Pause"))
            onClicked: {
                if (root.phase === "idle")
                    root.start();
                else if (root.paused)
                    root.resume();
                else
                    root.pause();
            }
        }

        Controls.Button {
            Layout.alignment: Qt.AlignHCenter
            flat: true
            icon.name: "view-refresh"
            text: i18n("Reset")
            enabled: root.phase !== "idle" || root.done
            opacity: enabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            onClicked: root.reset()
        }
    }
}
