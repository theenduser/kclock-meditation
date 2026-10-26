import QtQuick
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

    function fmt(s) {
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function ring() {
        bell.stop();
        bell.position = 0;
        bell.play();
    }

    function start() {
        phase = "preparing";
        phaseEnd = Date.now() + prepBox.value * 1000;
        tick.start();
    }

    function stop() {
        tick.stop();
        phase = "idle";
    }

    MediaPlayer {
        id: bell
        source: "file:///usr/share/sounds/freedesktop/stereo/complete.oga"
        audioOutput: AudioOutput {}
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
                    root.ring();
                    root.sessionEnd = now + lengthBox.value * 60000;
                    root.nextInterval = intervalBox.value > 0 ? now + intervalBox.value * 60000 : 0;
                }
            } else if (root.phase === "running") {
                root.remaining = Math.max(0, Math.ceil((root.sessionEnd - now) / 1000));
                if (now >= root.sessionEnd) {
                    root.ring();
                    root.stop();
                } else if (root.nextInterval > 0 && now >= root.nextInterval && root.nextInterval < root.sessionEnd) {
                    root.ring();
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
