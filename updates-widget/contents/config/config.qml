import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: configPage
    property alias cfg_pollInterval: pollIntervalSpinBox.value

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        GroupBox {
            title: "General"
            Layout.fillWidth: true
            ColumnLayout {
                anchors.fill: parent
                RowLayout {
                    Label { text: "Check interval (seconds):" }
                    SpinBox {
                        id: pollIntervalSpinBox
                        from: 300; to: 86400
                        Layout.fillWidth: true
                    }
                }
                Label {
                    text: "Default: 3600 (1 hour)"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.6
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
