'''
This module provides wrappers around the objective-c model classes
of QSX (QSXWindow, QSXApp, QSXWindowManager) to make them usable from Python/PyObjC
'''

from utils import config, BORDERLESS_APPS
from Foundation import NSClassFromString, NSMakeRect
from Foundation import NO
from AppKit import NSApp, NSRunningApplication, NSBorderlessWindowMask, NSBackingStoreBuffered,\
    NSScreen

QSXWindowManager = NSClassFromString("QSXWindowManager")
QSXApp = NSClassFromString("QSXApp")
QSXWindow = NSClassFromString("QSXWindow")
QSXOverlay = NSClassFromString("QSXOverlay")


class App(QSXApp):
    """Represents an OSX-Application
    Mainly a container for windows"""
    def init(self):
        self = super(App, self).init()
        return self

    @property
    def name(self):
        return self._name()

    @property
    def identifier(self):
        return self._identifier()

    @property
    def pid(self):
        return self._pid()

    @property
    def windows(self):
        return self._windows()

    def hide_menu_and_dock(self, val):
        self.setAccessibilityFlag_toValue_("QSXHideMenuAndDock", val)


class Window(QSXWindow):
    """represents a OSX-Window, with position, size and title"""
    def init(self):
        self = super(Window, self).init()
        self.is_static = False
        self.had_lion_fullscreen = None
        self.layout = None
        return self

    def __repr__(self):
        return self.app.name.encode("utf-8") + ": " +\
            self.title.encode("utf-8")+ " x:%i,y:%i,w:%i,h:%i"\
            % (self.x, self.y, self.width, self.height)

    @property
    def app(self):
        return self._app()

    @property
    def title(self):
        return self._title()

    @property
    def subrole(self):
        return self._subrole()

    @property
    def space(self):
        return self.windowSpace()

    @property
    def width(self):
        return self._size().width

    @property
    def height(self):
        return self._size().height

    @property
    def size(self):
        return self._size()

    @property
    def frame(self):
        pos = self._position()
        size = self._size()
        return NSMakeRect(pos.x, pos.y, size.width, size.height)

    @property
    def x(self):
        return self._position().x

    @property
    def y(self):
        return self._position().y

    def move_by(self, x, y):
        self.moveByX_Y_(x, y)

    def move_to(self, x, y):
        self.moveToX_Y_(x, y)

    def resize_by(self, width, height):
        self.resizeByWidth_height_(width, height)

    def resize_to(self, width, height):
        self.resizeToWidth_height_(width, height)

    def focus(self):
        self.focusWindow()

    def set_static(self, val):
        if val != self.is_static:
            if self.app.name in config[BORDERLESS_APPS]:
                self.setAccessibilityFlag_toValue_(
                    "QSXStaticBorderless", val)
            # elif self.app.identifier == "com.google.Chrome":
            #     return
            else:
                self.setAccessibilityFlag_toValue_(
                    "QSXStatic", val)
            self.is_static = val

    def toggle_lion_fullscreen(self):
        # TODO: it's not a real toggle in the original sense of the word toggle
        if self.had_lion_fullscreen is None:
            self.had_lion_fullscreen = self.accessibilityFlag_("QSXIsLionFullscreenEnabled")
            self.setAccessibilityFlag_toValue_(
                    "QSXSetLionFullscreenEnabled", False)
        else:
            if self.had_lion_fullscreen:
                self.setAccessibilityFlag_toValue_(
                    "QSXSetLionFullscreenEnabled", True)

    def place(self, x, y, w, h, bw, bc):
        '''compatibility with qtile layouts'''
        self.move_to(x, y)
        self.resize_to(w, h)

    def hide(self):
        '''compatibility with qtile layouts'''
        pass

    def unhide(self):
        '''compatibility with qtile layouts'''
        pass


class WindowManager(object):

    @classmethod
    def current_space(cls):
        return QSXWindowManager.sharedManager().currentSpace()

    @classmethod
    def toggle_shadows(cls, val):
        QSXWindowManager.sharedManager().toggleShadows_(val)

    @classmethod
    def runnning_apps(cls):
        return QSXWindowManager.sharedManager().apps()

    @classmethod
    def still_running(cls, apps):
        result = []
        for app in apps:
            r = NSRunningApplication.runningApplicationsWithBundleIdentifier_(app.identifier)
            if r.count() > 0:
                result.append(app)
        return result

    @classmethod
    def screens(cls):
        return NSScreen.screens()

class Overlay(QSXOverlay):

    def initWithScreen_(self, screen):
        self = super(Overlay, self).initWithContentRect_styleMask_backing_defer_mode_(
                screen.frame(),
                NSBorderlessWindowMask, NSBackingStoreBuffered, NO, "borders_mode")
        self.makeKeyAndOrderFront_(NSApp)
        self.orderBack_(NSApp)
        return self