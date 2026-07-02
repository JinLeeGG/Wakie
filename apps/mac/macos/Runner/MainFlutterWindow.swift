import Cocoa
import FlutterMacOS
import macos_window_utils

class MainFlutterWindow: NSWindow {
  // Design canvas the Flutter UI is authored against (1x). The window is sized
  // as a fraction of the active display while preserving this aspect ratio, so
  // the content scales to fill without any per-element hardcoded sizes.
  private let designWidth: CGFloat = 1000
  private let designHeight: CGFloat = 640

  override func awakeFromNib() {
    let macOSWindowUtilsViewController = MacOSWindowUtilsViewController()
    self.contentViewController = macOSWindowUtilsViewController

    // Initialize the macos_window_utils plugin.
    MainFlutterWindowManipulator.start(mainFlutterWindow: self)

    RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)

    // Tray <-> window control channel.
    let channel = FlutterMethodChannel(
      name: "wakieai/window",
      binaryMessenger: macOSWindowUtilsViewController.flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "show":
        let target = self.screenUnderCursor()
        if !self.isVisible { self.positionOnScreen(target) }
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
      case "hide":
        self.orderOut(nil)
      case "toggle":
        // The clicked menubar lives on the display under the cursor.
        let target = self.screenUnderCursor()
        let onSameScreen = self.isVisible && self.screen == target
        let isFrontmost = self.isVisible && NSApp.isActive && self.isKeyWindow
        if onSameScreen && isFrontmost {
          // Already up front on this display -> tuck it away.
          self.orderOut(nil)
        } else if onSameScreen {
          // Visible but buried on this display -> pull it forward, keep position.
          self.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
        } else {
          // Hidden, or living on another display -> place it on the clicked one.
          self.positionOnScreen(target)
          self.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
        }
      case "quit":
        NSApp.terminate(nil)
      default:
        break
      }
      result(nil)
    }

    // Frameless, transparent, fixed-size glass panel.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.styleMask.remove(.resizable) // size is display-driven, not user-driven
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true
    self.isMovableByWindowBackground = true
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = true
    // Appear on whichever Space / fullscreen app is currently active,
    // instead of yanking the user back to the Space the window was on.
    self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

    // Rounded corners on the content so the vibrancy is clipped to the panel shape.
    if let contentView = self.contentView {
      contentView.wantsLayer = true
      contentView.layer?.masksToBounds = true
    }

    positionOnScreen(self.screen ?? NSScreen.main)
    self.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    super.awakeFromNib()
  }

  /// The display the mouse cursor is currently on (i.e. the menubar just clicked).
  private func screenUnderCursor() -> NSScreen? {
    let loc = NSEvent.mouseLocation
    return NSScreen.screens.first(where: { NSMouseInRect(loc, $0.frame, false) })
      ?? NSScreen.main
  }

  /// Sizes the window to a fraction of the given display, keeping the design
  /// aspect ratio and clamping, then centers it within that display.
  private func positionOnScreen(_ screen: NSScreen?) {
    guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
    let aspect = designWidth / designHeight

    // Target ~50% of the display width, clamped to a sensible absolute range so
    // it never gets tiny on small screens or huge on large ones.
    var w = min(max(visible.width * 0.52, 900.0), 1040.0)
    var h = w / aspect

    let maxH = visible.height * 0.86
    if h > maxH { h = maxH; w = h * aspect }

    self.setContentSize(NSSize(width: w.rounded(), height: h.rounded()))

    // Center within the target display's visible area.
    let frame = self.frame
    let x = visible.origin.x + (visible.width - frame.width) / 2
    let y = visible.origin.y + (visible.height - frame.height) / 2
    self.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))

    // Keep the native corner radius matched to the scaled panel radius (22 @ 900).
    self.contentView?.layer?.cornerRadius = (22.0 * (w / designWidth)).rounded()
  }
}
