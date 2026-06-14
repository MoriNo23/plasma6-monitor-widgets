import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: configPage
    property alias cfg_pollInterval: pollIntervalSpinBox.value
    property alias cfg_showGraph: showGraphCheckBox.checked
    property alias cfg_showTopProcesses: showTopProcessesCheckBox.checked
    property alias cfg_showPerCore: showPerCoreCheckBox.checked

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        GroupBox {
            title: "General"
            Layout.fillWidth: true
            ColumnLayout {
                anchors.fill: parent
                RowLayout {
                    Label { text: "Update interval (seconds):" }
                    SpinBox {
                        id: pollIntervalSpinBox
                        from: 1; to: 30
                        Layout.fillWidth: true
                    }
                }
            }
        }

        GroupBox {
            title: "Expanded View"
            Layout.fillWidth: true
            ColumnLayout {
                anchors.fill: parent
                CheckBox {
                    id: showGraphCheckBox
                    text: "Show history graph"
                }
                CheckBox {
                    id: showTopProcessesCheckBox
                    text: "Show top processes"
                }
                CheckBox {
                    id: showPerCoreCheckBox
                    text: "Show per-core breakdown"
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
