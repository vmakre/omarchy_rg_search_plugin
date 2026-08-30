import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// ag search — a bar button that opens a popup search field. Type a query and
// press Enter to search the tree with ag; Up/Down step through the matches
// and Enter opens the selected one in the default editor. Esc clears the
// query, Esc again closes the popup.

Panel {
  id: root
  moduleName: "ag_search"
  ipcTarget: "ag_search"
  manageIpc: false

  // --- settings (inline on the shell.json layout entry) ---
  readonly property string prompt: setting("prompt", "🔍 ")
  readonly property string folderSetting: setting("folder", "~")

  // --- theme passthrough ---
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Resolved from this file's own directory so the plugin can live anywhere.
  readonly property string openHelper:
    String(Qt.resolvedUrl("bin/ag-open")).replace(/^file:\/\//, "")

  // --- search root ---
  readonly property string searchRoot: {
    var h = bar ? bar.home : Quickshell.env("HOME")
    var f = folderSetting
    if (!f || f === "~") return h
    if (f.indexOf("~/") === 0) return h + f.substring(1)
    return f
  }

  // --- state ---
  property string query: ""
  property var results: []
  property int cursor: 0
  property bool busy: false
  property bool timedOut: false
  property string status: "" // "" | "empty" | "none" | "error" | "timeout"

  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  function runSearch() {
    var q = query.trim()
    if (q === "") {
      results = []
      cursor = 0
      status = "empty"
      return
    }
    if (searchProc.running) return
    timedOut = false
    busy = true
    status = ""
    results = []
    cursor = 0
    // Quickshell gives every Process a pipe on stdin, and ag treats a pipe
    // (or regular file) on stdin as stream mode ("tail -f | ag"): even with
    // a search path it then drops the filename from every result line, so
    // we would only ever see bare "line:text" and could not tell which file
    // a match came from. Redirecting stdin from /dev/null keeps ag in normal
    // path-searching mode, restoring "path:line:text" output. The query and
    // root travel as positional args, so no shell quoting can corrupt them.
    searchProc.command = [
      "bash", "-c",
      "exec ag --nogroup --nocolor --numbers -- \"$1\" \"$2\" < /dev/null",
      "ag-search", q, searchRoot
    ]
    timeoutTimer.restart()
    searchProc.running = true
  }

  function applyResults(raw) {
    if (timedOut) return
    busy = false
    var parsed = []
    var lines = raw.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var s = lines[i].replace(/\r$/, "")
      if (s === "") continue
      var file
      var line
      var bare = /^(\d+):(.*)$/.exec(s)
      if (bare) {
        // Single-file search root: ag omits the path and prints bare
        // "line:text". The file is the search root itself.
        line = bare[1]
        file = searchRoot
      } else {
        // Folder search: ag prints "path:line:text"; anchor on the numeric
        // line number so colons in a path can't shift the fields.
        var m = /^(.*?):(\d+):(.*)$/.exec(s)
        if (!m) continue
        file = m[1]
        line = m[2]
      }
      parsed.push({ file: file, line: line })
      if (parsed.length >= 50) break
    }
    // Assign once so the Repeater model binding re-evaluates. Mutating the
    // array in place (results.push) never notifies QML.
    results = parsed
    cursor = 0
    status = parsed.length === 0 ? "none" : ""
  }

  function moveCursor(delta) {
    if (results.length === 0) return
    cursor = Math.max(0, Math.min(results.length - 1, cursor + delta))
  }

  function activateSelected() {
    if (results.length === 0) return
    var r = results[cursor]
    if (r) {
      Quickshell.execDetached([openHelper, r.file, String(r.line)])
    }
  }

  function clearQuery() {
    query = ""
    results = []
    cursor = 0
    status = ""
    if (searchField) searchField.text = ""
  }

  // A property (not a function) so the Text binding below tracks `busy`,
  // `status`, and `results` reactively — a JS function called from a binding
  // reads those values without QML ever learning to re-evaluate.
  readonly property string statusLabel:
    busy ? "Searching…"
    : status === "empty" ? "Type a query and press Enter"
    : status === "none" ? "No matches"
    : status === "timeout" ? "Search timed out"
    : status === "error" ? "ag failed — check the search root and that ag is installed"
    : results.length > 0 ? results.length + (results.length === 1 ? " match" : " matches")
    : ""

  // --- search process ---
  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyResults(text)
    }
    onExited: function (code) {
      if (root.timedOut) return
      root.busy = false
      if (code === 1) {
        root.results = []
        root.cursor = 0
        root.status = "none"
      } else if (code !== 0) {
        root.results = []
        root.cursor = 0
        root.status = "error"
      }
    }
  }

  Timer {
    id: timeoutTimer
    interval: 8000
    repeat: false
    onTriggered: {
      if (!root.busy) return
      root.timedOut = true
      root.busy = false
      root.results = []
      root.status = "timeout"
      try { searchProc.signal(15) } catch (e) {}
    }
  }

  onOpenedChanged: {
    if (opened) {
      Qt.callLater(function () {
        if (searchField) searchField.forceActiveFocus()
        if (searchField) searchField.selectAll()
      })
    }
  }

  // --- bar face ---
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "" // nf-fa-search
    active: root.opened || root.results.length > 0
    tooltipText: "ag search"
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  // --- popup ---
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onMoveRequested: function (dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateSelected()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(8)

        Row {
          width: parent.width
          spacing: Style.space(6)

          Text {
            id: promptText
            text: root.prompt
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            id: searchField
            width: parent.width - promptText.width - Style.space(6)
            placeholderText: "search with ag…"
            foreground: root.foreground
            font.family: root.fontFamily
            onTextChanged: root.query = text
            Keys.onPressed: function (event) {
              if (event.key === Qt.Key_Escape) {
                if (root.query !== "") root.clearQuery()
                else root.close()
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.runSearch()
                event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.moveCursor(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.moveCursor(-1)
                event.accepted = true
              }
            }
          }
        }

        Text {
          visible: text !== ""
          width: parent.width
          text: root.statusLabel
          color: (root.status === "error" || root.status === "timeout") ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Flickable {
          id: listFlick
          width: parent.width
          height: Math.min(listCol.implicitHeight, Style.space(360))
          contentHeight: listCol.implicitHeight
          clip: true
          interactive: listCol.implicitHeight > height
          flickableDirection: Flickable.VerticalFlick
          visible: root.results.length > 0

          Column {
            id: listCol
            width: parent.width
            spacing: Style.space(2)

            Repeater {
              model: root.results

              delegate: Rectangle {
                required property var modelData
                required property int index

                width: listCol.width
                height: rowText.implicitHeight + Style.space(4)
                radius: Style.cornerRadius
                color: index === root.cursor
                  ? Style.hoverFillFor(root.foreground, root.accent)
                  : "transparent"

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: root.cursor = index
                  onClicked: root.activateSelected()
                }

                Text {
                  id: rowText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.space(3)
                  anchors.rightMargin: Style.space(3)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.file + ":" + modelData.line
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideMiddle
                }
              }
            }
          }
        }
      }
    }
  }
}
