import QtQuick
import QtCore
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root
    objectName: "Meditation"
    title: i18n("Meditation")

    property string phase: "idle" // idle | preparing | running
    property double phaseEnd: 0
    property double sessionEnd: 0
    property int remaining: 0

    property bool useFirstPlayer: true
    property int ringsLeft: 0

    // remembers prep time and session length between runs
    Settings {
        category: "Meditation"
        property alias prep: prepBox.value
        property alias length: lengthBox.value
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
        phase = "preparing";
        phaseEnd = Date.now() + prepBox.value * 1000;
        tick.start();
    }

    // Stop button: silence everything
    function stop() {
        tick.stop();
        ringer.stop();
        phase = "idle";
    }

    // session ran to the end: 2 closing strikes
    function finish() {
        tick.stop();
        phase = "idle";
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
                    root.sessionEnd = now + lengthBox.value * 60000;
                }
            } else if (root.phase === "running") {
                root.remaining = Math.max(0, Math.ceil((root.sessionEnd - now) / 1000));
                if (now >= root.sessionEnd) {
                    root.finish();
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 1
            font.pointSize: 48
            text: root.phase === "idle" ? root.fmt(lengthBox.value * 60) : root.fmt(root.remaining)
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

            Repeater {
                model: [15, 20, 25]
                Controls.Button {
                    Layout.fillWidth: true
                    text: i18n("%1 min", modelData)
                    onClicked: lengthBox.value = modelData
                }
            }
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            enabled: root.phase === "idle"

            Controls.Label { text: i18n("Preparation (s)") }
            Controls.SpinBox { id: prepBox; from: 0; to: 120; value: 10 }

            Controls.Label { text: i18n("Session (min)") }
            Controls.SpinBox { id: lengthBox; from: 1; to: 240; value: 20 }
        }

        Controls.Button {
            Layout.alignment: Qt.AlignHCenter
            icon.name: root.phase === "idle" ? "media-playback-start" : "media-playback-stop"
            text: root.phase === "idle" ? i18n("Sit") : i18n("Stop")
            onClicked: root.phase === "idle" ? root.start() : root.stop()
        }
    }
}
