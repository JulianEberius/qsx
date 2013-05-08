from objc import IBAction, IBOutlet
from Foundation import NSObject
from AppKit import NSApp, NSStatusBar, NSImage

import utils
import hotkeys
from qsx import QSX


class QSXAppDelegate(NSObject):

    status_menu = IBOutlet()

    @IBAction
    def exit_(self, sender):
        NSApp.terminate_(None)

    @IBAction
    def someTest_(self, sender):
        self.qsx.test()

    @IBAction
    def doStuff_(self, sender):
        self.qsx.run()

    def awakeFromNib(self):
        self.initStatusBarItem()
        hotkeys.init_default_delegate_hotkeys(self)
        self.qsx = QSX.alloc().init()

    def initStatusBarItem(self):
        iconPath = utils.resource_path("qsx", "png")
        self.statusMenuItemIcon = NSImage.alloc().\
            initWithContentsOfFile_(iconPath)
        self.statusItem = NSStatusBar.\
            systemStatusBar().statusItemWithLength_(20)
        self.statusItem.setMenu_(self.status_menu)
        self.statusItem.setTitle_("QSX")
        self.statusItem.setImage_(self.statusMenuItemIcon)

    def applicationDidFinishLaunching_(self, sender):
        pass

    def applicationWillTerminate_(self, notfification):
        self.qsx.terminate()

