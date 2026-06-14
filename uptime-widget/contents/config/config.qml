import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: configPage
    property alias cfg_pollInterval: pollIntervalSpinBox.value
    property alias cfg_showRebootHistory: showRebootHistoryCheckBox.checked

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
                        from: 5; to: 300
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
                    id: showRebootHistoryCheckBox
                    text: "Show reboot history"
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
