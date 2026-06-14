import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root
    implicitWidth: 100
    implicitHeight: 40

    property int pollInterval: 30
    property bool showRebootHistory: true

    property int uptimeDays: 0
    property int uptimeHours: 0
    property int uptimeMinutes: 0
    property string statusColor: "#27ae60"
    property var reboots: []
    property bool showConfirm: false

    readonly property string dbusService: "com.github.fullmetal.monitor"
    readonly property string dbusPath: "/Monitor"
    readonly property string dbusIface: "com.github.fullmetal.monitor"

    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.minimumWidth: 80
        Layout.maximumWidth: 120

        Rectangle {
            width: 8; height: 8; radius: 4
            color: root.statusColor
        }

        Label {
            text: {
                if (root.uptimeDays > 0)
                    return root.uptimeDays + "d " + root.uptimeHours + "h"
                else
                    return root.uptimeHours + "h " + root.uptimeMinutes + "m"
            }
            font.family: "Monospace"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: root.statusColor
            style: Text.Outline
            styleColor: "#222222"
        }
    }

    fullRepresentation: ColumnLayout {
        implicitWidth: 320
        implicitHeight: 380
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "system-reboot-symbolic"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Label {
                text: "Uptime & Reboot"
                font.bold: true
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            Label {
                text: root.uptimeDays + " days " + root.uptimeHours + " hours " + root.uptimeMinutes + " minutes"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                font.bold: true
                color: root.statusColor
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                text: {
                    if (root.statusColor === "#27ae60")
                        return "System running normally"
                    else if (root.statusColor === "#f39c12")
                        return "Consider restarting soon"
                    else
                        return "Restart recommended!"
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: root.statusColor
                opacity: 0.8
                Layout.alignment: Qt.AlignHCenter
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showRebootHistory && root.reboots.length > 0
            spacing: 2
            Label {
                text: "Recent Reboots"
                font.bold: true
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.reboots
                clip: true
                delegate: RowLayout {
                    width: ListView.view.width
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: "system-reboot-symbolic"
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        opacity: 0.6
                    }
                    ColumnLayout {
                        spacing: 0
                        Label {
                            text: modelData.date
                            font.family: "Monospace"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                        Label {
                            text: modelData.desc
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                            opacity: 0.6
                            visible: modelData.desc.length > 0
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Button {
                text: root.showConfirm ? "Confirm Reboot" : "Reboot System"
                icon.name: "system-reboot-symbolic"
                Layout.fillWidth: true
                enabled: !root.showConfirm
                onClicked: root.showConfirm = true

                background: Rectangle {
                    radius: 4
                    color: root.showConfirm ? "#e74c3c" : Qt.rgba(1, 1, 1, 0.1)
                    border.color: root.showConfirm ? "#c0392b" : Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                }
                contentItem: Label {
                    text: parent.text
                    color: root.showConfirm ? "white" : Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Button {
                text: "Cancel"
                Layout.fillWidth: true
                visible: root.showConfirm
                onClicked: root.showConfirm = false
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Label {
                text: "Updated just now"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
            }
        }
    }

    Timer {
        id: pollTimer
        interval: root.expanded ? 30000 : root.pollInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchUptimeData()
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

    function fetchUptimeData() {
        var reply = dbusCall("GetUptimeInfo")
        if (reply) {
            reply.finished.connect(function() {
                if (reply.isFinished && !reply.isError && reply.value) {
                    try {
                        var d = JSON.parse(reply.value.toString())
                        root.uptimeDays = d.days
                        root.uptimeHours = d.hours
                        root.uptimeMinutes = d.minutes
                        root.reboots = d.reboots || []

                        if (d.level === "green")
                            root.statusColor = "#27ae60"
                        else if (d.level === "yellow")
                            root.statusColor = "#f39c12"
                        else
                            root.statusColor = "#e74c3c"
                    } catch(e) {}
                }
            })
        }
    }
}
