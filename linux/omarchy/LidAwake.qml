// Lid Awake for the Omarchy bar: the Linux counterpart of the macOS menu bar app.
// A coffee cup, lit while lid-closed stay-awake is on and dimmed while it is off;
// a click toggles it. Everything goes through the lid-awake CLI that installed
// this widget (`lid-awake menubar enable` bakes its path in below), the same
// contract as the Mac app: `status --porcelain` prints state=on|off.
import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "lid-awake"

  readonly property string bin: "__LID_AWAKE_BIN__"
  property bool on: false
  property bool known: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  Component.onCompleted: refresh()

  // `lid-awake on` from a terminal shows up here within a few seconds. Each
  // check is one `systemctl --user is-active`.
  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.bin, "status", "--porcelain"]
    environment: ({ "LID_AWAKE_NO_UPDATE_CHECK": "1" })
    stdout: StdioCollector {
      onStreamFinished: {
        root.on = /^state=on$/m.test(this.text)
        root.known = /^state=(on|off)$/m.test(this.text)
      }
    }
  }

  Process {
    id: toggleProc
    command: [root.bin, root.on ? "off" : "on"]
    environment: ({ "LID_AWAKE_NO_UPDATE_CHECK": "1", "LID_AWAKE_GUI": "1" })
    onExited: function(exitCode, exitStatus) {
      if ((exitCode !== 0 || exitStatus !== 0) && root.bar)
        Util.execArgv(["omarchy-notification-send", strings.t("notify.failed"), strings.t("notify.failedBody")])
      root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰅶"
    active: root.on
    dimmed: !root.on
    useActiveColor: false
    tooltipText: root.on ? strings.t("tooltip.on") : strings.t("tooltip.off")
    onPressed: function(b) {
      if (b !== Qt.LeftButton || toggleProc.running || !root.known) return
      toggleProc.running = true
    }
  }
}
