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

    property int pollInterval: 3
    property bool showGraph: true
    property bool showTopProcesses: true
    property bool showPerCore: true

    property real cpuPercent: 0
    property var cpuHistory: []
    property var perCore: ({})
    property var topCpu: []
    property string statusColor: "#27ae60"

    readonly property string dbusService: "com.github.fullmetal.monitor"
    readonly property string dbusPath: "/Monitor"
    readonly property string dbusIface: "com.github.fullmetal.monitor"

    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.minimumWidth: 80
        Layout.maximumWidth: 120

        Canvas {
            id: circleCanvas
            width: 20; height: 20
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2, cy = height / 2, r = 8
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
                ctx.lineWidth = 3
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + (root.cpuPercent / 100) * Math.PI * 2)
                ctx.strokeStyle = root.statusColor
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                ctx.stroke()
            }
            Connections {
                target: root
                function onCpuPercentChanged() { circleCanvas.requestPaint() }
                function onStatusColorChanged() { circleCanvas.requestPaint() }
            }
        }

        Label {
            text: root.cpuPercent.toFixed(1) + "%"
            font.family: "Monospace"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: root.statusColor
            style: Text.Outline
            styleColor: "#222222"
        }
    }

    fullRepresentation: ColumnLayout {
        implicitWidth: 320
        implicitHeight: 420
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "cpu-symbolic"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Label {
                text: "CPU Monitor"
                font.bold: true
                Layout.fillWidth: true
            }
            Label {
                text: root.cpuPercent.toFixed(1) + "%"
                font.family: "Monospace"
                font.bold: true
                color: root.statusColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Rectangle {
                Layout.fillWidth: true; height: 14; radius: 3
                color: Qt.rgba(1, 1, 1, 0.1)
                Rectangle {
                    width: parent.width * (root.cpuPercent / 100)
                    height: parent.height; radius: 3
                    color: root.statusColor
                }
            }
        }

        Canvas {
            id: cpuGraph
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            visible: root.showGraph

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (root.cpuHistory.length < 2) return

                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
                ctx.lineWidth = 1
                for (var y = 0; y <= 100; y += 25) {
                    var yy = height - (y / 100) * height
                    ctx.beginPath()
                    ctx.moveTo(0, yy)
                    ctx.lineTo(width, yy)
                    ctx.stroke()
                }

                ctx.beginPath()
                ctx.moveTo(0, height)
                for (var i = 0; i < root.cpuHistory.length; i++) {
                    var x = (i / (root.cpuHistory.length - 1)) * width
                    var v = height - (root.cpuHistory[i] / 100) * height
                    ctx.lineTo(x, v)
                }
                ctx.lineTo(width, height)
                ctx.closePath()
                var grad = ctx.createLinearGradient(0, 0, 0, height)
                grad.addColorStop(0, Qt.rgba(0.2, 0.6, 1.0, 0.5))
                grad.addColorStop(1, Qt.rgba(0.2, 0.6, 1.0, 0.05))
                ctx.fillStyle = grad
                ctx.fill()

                ctx.beginPath()
                for (var i = 0; i < root.cpuHistory.length; i++) {
                    var x = (i / (root.cpuHistory.length - 1)) * width
                    var v = height - (root.cpuHistory[i] / 100) * height
                    if (i === 0) ctx.moveTo(x, v)
                    else ctx.lineTo(x, v)
                }
                ctx.strokeStyle = "#3498db"
                ctx.lineWidth = 2
                ctx.stroke()
            }

            Connections {
                target: root
                function onCpuHistoryChanged() { cpuGraph.requestPaint() }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showPerCore && Object.keys(root.perCore).length > 0
            spacing: 2
            Label { text: "Per Core"; font.bold: true }
            Repeater {
                model: Object.keys(root.perCore)
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: modelData
                        font.family: "Monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        Layout.preferredWidth: 40
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 10; radius: 2
                        color: Qt.rgba(1, 1, 1, 0.1)
                        Rectangle {
                            width: parent.width * (root.perCore[modelData] / 100)
                            height: parent.height; radius: 2
                            color: root.perCore[modelData] > 80 ? "#e74c3c" : root.perCore[modelData] > 50 ? "#f39c12" : "#3498db"
                        }
                    }
                    Label {
                        text: root.perCore[modelData].toFixed(0) + "%"
                        font.family: "Monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        Label {
            text: "Top 5 CPU"
            font.bold: true
            visible: root.showTopProcesses
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showTopProcesses
            model: root.topCpu
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
                    text: modelData.time
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
        onTriggered: root.fetchCpuData()
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

    function fetchCpuData() {
        var reply = dbusCall("GetCpuInfo")
        if (reply) {
            reply.finished.connect(function() {
                if (reply.isFinished && !reply.isError && reply.value) {
                    try {
                        var d = JSON.parse(reply.value.toString())
                        root.cpuPercent = d.cpu_percent
                        root.cpuHistory = d.cpu_history || []
                        root.perCore = d.per_core || {}
                        root.topCpu = d.top_cpu || []

                        if (root.cpuPercent < 50)
                            root.statusColor = "#27ae60"
                        else if (root.cpuPercent < 80)
                            root.statusColor = "#f39c12"
                        else
                            root.statusColor = "#e74c3c"
                    } catch(e) {}
                }
            })
        }
    }
}
