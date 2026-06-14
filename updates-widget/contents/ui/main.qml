import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root
    implicitWidth: 80
    implicitHeight: 40

    property int pollInterval: 3600
    property int updateCount: 0

    readonly property string dbusService: "com.github.fullmetal.monitor"
    readonly property string dbusPath: "/Monitor"
    readonly property string dbusIface: "com.github.fullmetal.monitor"

    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.minimumWidth: 60
        Layout.maximumWidth: 100

        Kirigami.Icon {
            source: "system-software-update"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            color: root.updateCount > 0 ? "#f39c12" : Kirigami.Theme.textColor
        }

        Label {
            text: root.updateCount > 0 ? root.updateCount : ""
            font.family: "Monospace"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.bold: root.updateCount > 0
            color: root.updateCount > 0 ? "#f39c12" : Kirigami.Theme.textColor
        }
    }

    fullRepresentation: ColumnLayout {
        implicitWidth: 280
        implicitHeight: 200
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "system-software-update"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Label {
                text: "Package Updates"
                font.bold: true
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            Label {
                text: root.updateCount > 0
                    ? root.updateCount + " updates available"
                    : "System is up to date"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                font.bold: true
                color: root.updateCount > 0 ? "#f39c12" : "#27ae60"
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.05)

                Label {
                    anchors.centerIn: parent
                    text: root.updateCount > 0
                        ? "Run: sudo apt update && apt list --upgradable"
                        : "No updates pending"
                    font.family: "Monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Label {
                text: "Checked " + formatInterval(root.pollInterval) + " ago"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
            }
        }
    }

    function formatInterval(seconds) {
        if (seconds < 60) return seconds + "s"
        if (seconds < 3600) return Math.floor(seconds / 60) + "m"
        return Math.floor(seconds / 3600) + "h"
    }

    Timer {
        id: pollTimer
        interval: root.pollInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchUpdatesData()
    }

    function dbusCall(method) {
        var msg = {
            service: dbusService,
            path: dbusPath,
            iface: dbusIface,
            member: method,
            arguments: []
        }
        return DBus.SessionBus.asyncCall(msg)
    }

    function fetchUpdatesData() {
        var reply = dbusCall("GetUpdatesInfo")
        if (reply) {
            reply.finished.connect(function() {
                if (reply.isFinished && !reply.isError && reply.value) {
                    try {
                        var d = JSON.parse(reply.value.toString())
                        root.updateCount = d.count || 0
                    } catch(e) {}
                }
            })
        }
    }
}
