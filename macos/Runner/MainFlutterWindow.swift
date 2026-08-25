import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // OpsHub is a desktop-first operations app: its premium split/sidebar layout
    // only engages at >= 1024pt wide. The storyboard's ~800x600 default opened
    // below that breakpoint, so the app fell back to the cramped mobile layout.
    // Open at a comfortable desktop size and stop the user from shrinking it
    // below the desktop breakpoint, keeping the native macOS experience intact.
    // Premium macOS chrome: hide the window title text and let the title bar
    // blend into the app's near-black background (like Linear / Things), instead
    // of the default grey bar reading "OpsHub". The traffic-light buttons stay in
    // their standard position over a seamless dark strip. Content is NOT pushed
    // under the title bar, so nothing collides with the traffic lights.
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.backgroundColor = NSColor(
      red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0B / 255.0, alpha: 1.0)

    let minSize = NSSize(width: 1024, height: 720)
    self.minSize = minSize
    if let screen = self.screen ?? NSScreen.main {
      let visible = screen.visibleFrame
      let target = NSSize(
        width: min(1440, visible.width),
        height: min(900, visible.height)
      )
      self.setContentSize(target)
      self.center()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
