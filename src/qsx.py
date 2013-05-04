import models
import hotkeys
import utils
import osax
from utils import notification_receiver
from math import ceil
from qtileadapter import XMonadLayout, QTileGroupAdapter

from Foundation import NSObject, NSNotificationCenter

class QSX(NSObject):
    ''' this is it! the real window manager!'''

    def init(self):
        self = super(QSX, self).init()
        self.injected_apps = []
        self.groups = []
        self.active_space = None
        self.active_group = None
        self.setup_observers()
        hotkeys.init_default_qsx_hotkeys(self)
        utils.load_config()
        return self

    def setup_observers(self):
        # reaction to layout changes
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
            self, "layoutChanged:", "QSXLayoutChanged", None)

        # new, destroyed or focused windows are passed to the layout
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
            self, "newWindow:", "QSXNewWindow", None)
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
            self, "windowDestroyed:", "QSXWindowDestroyed", None)
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
            self, "windowFocusedExternal:", "QSXWindowFocusedExternal", None)
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
            self, "windowFocusedInternal:", "QSXWindowFocusedInternal", None)

        # new or destroyed apps are handled here
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
            self, "newApp:", "QSXNewApp", None)
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(
            self, "appDestroyed:", "QSXAppDestroyed", None)

    def run(self):
        self.active_space = models.WindowManager.current_space()
        apps = models.WindowManager.runnning_apps()

        windows = [w for app in apps for w in app.windows
                                    if w.subrole == "AXStandardWindow"
                                    and w.space == self.active_space]

        scripted_apps = [osax.ScriptingAddition(
                       "QSX", pid=a.pid) for a in apps]
        for sa in scripted_apps:
            try:
                sa.injectQSX()
            except Exception, e:
                print "Error injecting QSX-osax", e

        for a in apps:
            a.hide_menu_and_dock(True)
            for w in a.windows:
                w.toggle_lion_fullscreen()
        self.injected_apps = apps

        screens = models.WindowManager.screens()
        for s in screens:
            print s
            print s.frame().origin.x, s.frame().origin.y
            print s.frame().size.width, s.frame().size.height

        self.groups = []
        windows_per_screen = ceil(float(len(windows))/len(screens))
        for i, screen in enumerate(screens):
            _from = int(i * windows_per_screen)
            _to = int(min((i + 1) * windows_per_screen, len(windows)))
            screen_windows = windows[_from:_to]
            layout = XMonadLayout(screen_windows)
            overlay = models.Overlay.alloc().initWithScreen_(screen)
            group = QTileGroupAdapter(layout, screen, overlay)
            self.groups.append(group)
            layout.apply()
            for w in layout.windows:
                print w
        self.active_group = self.groups[0]
        self.active_group.focus_first()
        models.WindowManager.toggle_shadows(False)

    @notification_receiver
    def newWindow_(self, window):
        if window.space == self.active_space:
            self.active_group.layout.add_window(window)

    @notification_receiver
    def windowDestroyed_(self, window):
        for g in self.groups:
            if g.layout.contains(window):
                g.layout.remove_window(window)


    @notification_receiver
    def windowFocusedExternal_(self, focused_window):
        for g in self.groups:
            if g.layout.contains(focused_window):
                print "external focus switch", focused_window
                g.layout.focus_window(focused_window)
                self.active_group = g

    @notification_receiver
    def windowFocusedInternal_(self, focused_window):
        for g in self.groups:
            if g.layout.contains(focused_window):
                self.active_group = g

                ov = self.active_group.overlay
                ov.clear()
                windows = [w for w in g.layout.windows if w is not focused_window]
                for w in windows:
                    ov.addBorder_(w.frame)
                ov.addActiveBorder_(focused_window.frame)

    @notification_receiver
    def layoutChanged_(self, _):
        pass

    @notification_receiver
    def newApp_(self, app):
        scripted_app = osax.ScriptingAddition("QSX", pid=app.pid)
        scripted_app.injectQSX()
        self.injected_apps.append(app)
        app.hide_menu_and_dock(True)

        for w in app.windows:
            if w.space == self.active_space:
                if w.subrole == "AXStandardWindow":
                    w.toggle_lion_fullscreen()
                    self.active_group.layout.add_window(w)

    @notification_receiver
    def appDestroyed_(self, app):
        for w in app.windows:
            for g in self.groups:
                if g.layout.contains(w):
                    g.layout.remove_window(w)
        self.injected_apps.remove(app)

    def mouse_move_handler(self, event):
        self.select_window_under_cursor()

    def up_(self, sender):
        self.active_group.layout.cmd_up()

    def down_(self, sender):
        self.active_group.layout.cmd_down()

    def shuffleUp_(self, sender):
        self.active_group.layout.cmd_shuffle_up()

    def shuffleDown_(self, sender):
        self.active_group.layout.cmd_shuffle_down()

    def grow_(self, sender):
        self.active_group.layout.cmd_grow()

    def shrink_(self, sender):
        self.active_group.layout.cmd_shrink()

    def normalize_(self, sender):
        self.active_group.layout.cmd_normalize()

    def maximize_(self, sender):
        self.active_group.layout.cmd_maximize()

    def flip_(self, sender):
        self.active_group.layout.cmd_flip()

    def previous_(self, sender):
        self.active_group.layout.cmd_previous()

    def next_(self, sender):
        self.active_group.layout.cmd_next()

    def clientToPrevious_(self, sender):
        self.active_group.layout.cmd_client_to_previous()

    def clientToNext_(self, sender):
        self.active_group.layout.cmd_client_to_next()

    def terminate(self):
        models.WindowManager.toggle_shadows(True)

        for g in self.groups:
            for w in g.layout.windows:
                w.set_static(False)
                w.toggle_lion_fullscreen()

        still_running_apps = models.WindowManager.still_running(self.injected_apps)
        for a in still_running_apps:
            a.hide_menu_and_dock(False)
        scripted_apps = [osax.ScriptingAddition(
                        "QSX", name=a.name) for a in still_running_apps]
        for sa in scripted_apps:
                try:
                    sa.injectQSX()
                except Exception, e:
                    print "Error de-injecting QSX-osax", e
