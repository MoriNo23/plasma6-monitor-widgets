import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root
    implicitWidth: 150
    implicitHeight: 40

    property int pollInterval: 3
    property bool showSwap: true
    property bool showGraph: true
    property bool showTopProcesses: true

    property real ramPercent: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real swapPercent: 0
    property real swapUsedGb: 0
    property real swapTotalGb: 0
    property var ramHistory: []
    property var swapHistory: []
    property var topRam: []
    property var topSwap: []

    property string statusColor: "#27ae60"

    readonly property string dbusService: "com.github.fullmetal.monitor"
    readonly property string dbusPath: "/Monitor"
    readonly property string dbusIface: "com.github.fullmetal.monitor"

    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.minimumWidth: 120
        Layout.maximumWidth: 200

        Rectangle {
            width: 8; height: 8; radius: 4
            color: root.statusColor
        }

        ColumnLayout {
            spacing: 0
            Label {
                text: root.ramUsedGb.toFixed(1) + "G / " + root.ramTotalGb.toFixed(1) + "G"
                font.family: "Monospace"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: root.statusColor
                style: Text.Outline
                styleColor: "#222222"
            }
            Label {
                visible: root.showSwap && root.swapTotalGb > 0
                text: "S: " + root.swapUsedGb.toFixed(1) + "G / " + root.swapTotalGb.toFixed(1) + "G"
                font.family: "Monospace"
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                color: root.swapPercent > 80 ? "#e74c3c" : root.swapPercent > 50 ? "#f39c12" : "#27ae60"
                style: Text.Outline
                styleColor: "#222222"
            }
        }
    }

    fullRepresentation: ColumnLayout {
        implicitWidth: 320
        implicitHeight: 420
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "memory-symbolic"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Label {
                text: "RAM & Swap Monitor"
                font.bold: true
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Label { text: "RAM"; font.bold: true; Layout.preferredWidth: 40 }
                Label {
                    text: root.ramUsedGb.toFixed(1) + "G / " + root.ramTotalGb.toFixed(1) + "G (" + root.ramPercent.toFixed(1) + "%)"
                    font.family: "Monospace"
                }
            }
            Rectangle {
                Layout.fillWidth: true; height: 14; radius: 3
                color: Qt.rgba(1, 1, 1, 0.1)
                Rectangle {
                    width: parent.width * (root.ramPercent / 100)
                    height: parent.height; radius: 3
                    color: root.statusColor
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showSwap
            spacing: 2
            RowLayout {
                Label { text: "Swap"; font.bold: true; Layout.preferredWidth: 40 }
                Label {
                    text: root.swapUsedGb.toFixed(1) + "G / " + root.swapTotalGb.toFixed(1) + "G (" + root.swapPercent.toFixed(1) + "%)"
                    font.family: "Monospace"
                }
            }
            Rectangle {
                Layout.fillWidth: true; height: 14; radius: 3
                color: Qt.rgba(1, 1, 1, 0.1)
                Rectangle {
                    width: parent.width * (root.swapPercent / 100)
                    height: parent.height; radius: 3
                    color: root.swapPercent > 80 ? "#e74c3c" : root.swapPercent > 50 ? "#f39c12" : "#27ae60"
                }
            }
        }

        Canvas {
            id: ramGraph
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            visible: root.showGraph

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (root.ramHistory.length < 2) return

                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
                ctx.lineWidth = 1
                for (var y = 0; y < 100; y += 25) {
                    var yy = height - (y / 100) * height
                    ctx.beginPath()
                    ctx.moveTo(0, yy)
                    ctx.lineTo(width, yy)
                    ctx.stroke()
                }

                ctx.beginPath()
                ctx.moveTo(0, height)
                for (var i = 0; i < root.ramHistory.length; i++) {
                    var x = (i / (root.ramHistory.length - 1)) * width
                    var v = height - (root.ramHistory[i] / 100) * height
                    ctx.lineTo(x, v)
                }
                ctx.lineTo(width, height)
                ctx.closePath()
                var grad = ctx.createLinearGradient(0, 0, 0, height)
                grad.addColorStop(0, Qt.rgba(0.15, 0.68, 0.38, 0.5))
                grad.addColorStop(1, Qt.rgba(0.15, 0.68, 0.38, 0.05))
                ctx.fillStyle = grad
                ctx.fill()

                ctx.beginPath()
                for (var i = 0; i < root.ramHistory.length; i++) {
                    var x = (i / (root.ramHistory.length - 1)) * width
                    var v = height - (root.ramHistory[i] / 100) * height
                    if (i === 0) ctx.moveTo(x, v)
                    else ctx.lineTo(x, v)
                }
                ctx.strokeStyle = "#27ae60"
                ctx.lineWidth = 2
                ctx.stroke()
            }

            Connections {
                target: root
                function onRamHistoryChanged() { ramGraph.requestPaint() }
            }
        }

        Label {
            text: "Top 5 RAM"
            font.bold: true
            visible: root.showTopProcesses
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showTopProcesses
            model: root.topRam
            clip: true
            delegate: RowLayout {
                width: ListView.view.width
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: modelData.name
                    font.family: "Monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.preferredWidth: 100
                    elide: Text.ElideRight
                }
                Label {
                    text: modelData.percent.toFixed(1) + "%"
                    font.family: "Monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.preferredWidth: 45
                    horizontalAlignment: Text.AlignRight
                }
                Label {
                    text: (modelData.rss_kb / 1048576).toFixed(1) + "G"
                    font.family: "Monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
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
        interval: root.expanded ? 10000 : root.pollInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchRamData()
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

    function fetchRamData() {
        var reply = dbusCall("GetRamInfo")
        if (reply) {
            reply.finished.connect(function() {
                if (reply.isFinished && !reply.isError && reply.value) {
                    try {
                        var d = JSON.parse(reply.value.toString())
                        root.ramUsedGb = d.ram_used_gb
                        root.ramTotalGb = d.ram_total_gb
                        root.ramPercent = d.ram_percent
                        root.swapUsedGb = d.swap_used_gb
                        root.swapTotalGb = d.swap_total_gb
                        root.swapPercent = d.swap_percent
                        root.ramHistory = d.ram_history || []
                        root.swapHistory = d.swap_history || []
                        root.topRam = d.top_ram || []
                        root.topSwap = d.top_swap || []

                        if (root.ramPercent < 50)
                            root.statusColor = "#27ae60"
                        else if (root.ramPercent < 80)
                            root.statusColor = "#f39c12"
                        else
                            root.statusColor = "#e74c3c"
                    } catch(e) {}
                }
            })
        }
    }
}
