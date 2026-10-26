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
    property double nextInterval: 0
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

    // strike `count` times, 5 seconds apart
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

    MediaPlayer {
        id: bellA
        source: Qt.resolvedUrl("bell.wav")
        audioOutput: AudioOutput {}
    }

    MediaPlayer {
        id: bellB
        source: Qt.resolvedUrl("bell.wav")
        audioOutput: AudioOutput {}
    }

    // inaudible keep-alive so the Bluetooth speaker doesn't switch itself off
    MediaPlayer {
        id: keepAlive
        source: Qt.resolvedUrl("keepalive.wav")
        audioOutput: AudioOutput {}
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
        interval: 5000
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
                    root.nextInterval = intervalBox.value > 0 ? now + intervalBox.value * 60000 : 0;
                }
            } else if (root.phase === "running") {
                root.remaining = Math.max(0, Math.ceil((root.sessionEnd - now) / 1000));
                if (now >= root.sessionEnd) {
                    root.finish();
                } else if (root.nextInterval > 0 && now >= root.nextInterval && root.nextInterval < root.sessionEnd) {
                    root.ring(1);
                    root.nextInterval += intervalBox.value * 60000;
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
            columns: 2
            enabled: root.phase === "idle"

            Controls.Label { text: i18n("Preparation (s)") }
            Controls.SpinBox { id: prepBox; from: 0; to: 120; value: 10 }

            Controls.Label { text: i18n("Session (min)") }
            Controls.SpinBox { id: lengthBox; from: 1; to: 240; value: 20 }

            Controls.Label { text: i18n("Interval bell (min, 0 = off)") }
            Controls.SpinBox { id: intervalBox; from: 0; to: 120; value: 0 }
        }

        Controls.Button {
            Layout.alignment: Qt.AlignHCenter
            icon.name: root.phase === "idle" ? "media-playback-start" : "media-playback-stop"
            text: root.phase === "idle" ? i18n("Start") : i18n("Stop")
            onClicked: root.phase === "idle" ? root.start() : root.stop()
        }
    }
}
