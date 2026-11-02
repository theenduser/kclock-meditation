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
    property double phaseEnd: 0
    property double sessionStart: 0
    property double sessionEnd: 0
    property int remaining: 0
    property int sessionMinutes: 20

    // the digits fade out and the enso fades in over this many seconds after the first bell
    readonly property real fadeSeconds: sessionMinutes * 60
    property real fade: 0       // 0..1 while sitting
    property bool done: false   // the sit ran to the end: the enso stays visible
    readonly property real ensoOpacity: phase === "running" ? fade : (phase === "idle" && done ? 1 : 0)

    readonly property real ensoSize: Math.max(Kirigami.Units.gridUnit * 7,
                                              Math.min(Kirigami.Units.gridUnit * 15, root.height * 0.44))

    property bool useFirstPlayer: true
    property int ringsLeft: 0
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

    // play one strike, using the two players in turn so strikes can overlap
    function playOnce() {
        const p = useFirstPlayer ? bellA : bellB;
        useFirstPlayer = !useFirstPlayer;
        p.stop();
        p.play();
    }

    // strike `count` times, 6 seconds apart
    function ring(count) {
        playOnce();
        ringsLeft = count - 1;
        if (ringsLeft > 0)
            ringer.restart();
        else
            ringer.stop();
    }

    function start() {
        fade = 0;
        done = false;
        wakeSent = false;
        phase = "preparing";
        remaining = prepBox.value;
        phaseEnd = Date.now() + prepBox.value * 1000;
        tick.start();
    }

    // Stop button: silence everything
    function stop() {
        tick.stop();
        ringer.stop();
        phase = "idle";
        done = false;
        fade = 0;
    }

    // session ran to the end: the enso stays, 2 closing strikes
    function finish() {
        tick.stop();
        phase = "idle";
        done = true;
        ring(2);
    }

    // follows the system default audio output (e.g. a newly connected speaker)
    MediaDevices { id: mediaDevices }

    MediaPlayer {
        id: bellA
        source: Qt.resolvedUrl("bell.flac")
        audioOutput: AudioOutput { device: mediaDevices.defaultAudioOutput }
    }

    MediaPlayer {
        id: bellB
        source: Qt.resolvedUrl("bell.flac")
        audioOutput: AudioOutput { device: mediaDevices.defaultAudioOutput }
    }

    // inaudible keep-alive so the Bluetooth speaker doesn't switch itself off
    MediaPlayer {
        id: keepAlive
        source: Qt.resolvedUrl("keepalive.wav")
        audioOutput: AudioOutput { device: mediaDevices.defaultAudioOutput }
    }

    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: root.phase !== "idle"
        triggeredOnStart: true
        onTriggered: { keepAlive.stop(); keepAlive.play(); }
    }

    Timer {
        id: ringer
        interval: 6000
        repeat: true
        onTriggered: {
            root.playOnce();
            root.ringsLeft--;
            if (root.ringsLeft <= 0)
                ringer.stop();
        }
    }

    // drives the cross-fade while sitting
    Timer {
        interval: 100
        repeat: true
        running: root.phase === "running"
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
                if (now >= root.phaseEnd) {
                    root.phase = "running";
                    root.ring(3);
                    root.sessionStart = now;
                    root.sessionEnd = now + root.sessionMinutes * 60000;
                    root.remaining = root.sessionMinutes * 60;
                }
            } else if (root.phase === "running") {
                root.remaining = Math.max(0, Math.ceil((root.sessionEnd - now) / 1000));
                if (!root.wakeSent && root.remaining <= 4) {
                    root.wakeSent = true;
                    keepAlive.stop();
                    keepAlive.play();   // wake the speaker just before the closing bell
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
            visible: root.phase === "preparing"
            text: i18n("Get ready…")
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            enabled: root.phase === "idle"
            opacity: root.phase === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }

            Repeater {
                model: [10, 15, 20, 25, 30, 40]
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
            icon.name: root.phase === "idle" ? "media-playback-start" : "media-playback-stop"
            text: root.phase === "idle" ? i18n("Let’s sit!") : i18n("Stop")
            onClicked: root.phase === "idle" ? root.start() : root.stop()
        }
    }
}
