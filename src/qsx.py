import models
import hotkeys
import utils
import osax
from utils import notification_receiver, partition, supress_notification
from qtileadapter import XMonadLayout, QTileGroupAdapter

from Foundation import NSObject, NSNotificationCenter
from PyObjCTools.AppHelper import callLater

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

    def test(self):
        for w in self.active_group.layout.windows:
            w.toggle_dim()

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
                w.hide_lion_fullscreen_button()
        self.injected_apps = apps

        screens = models.WindowManager.screens()
        for s in screens:
            print s.frame()

        self.groups = []
        window_partitions = partition(windows, len(screens))
        for windows, screen in zip(window_partitions, screens):
            layout = XMonadLayout(windows)
            overlay = models.Overlay.alloc().initWithScreen_(screen)
            group = QTileGroupAdapter(layout, screen, overlay)
            self.groups.append(group)
            with supress_notification("QSXLayoutChanged"):
                layout.apply()
        self.active_group = self.groups[0]
        self.active_group.set_initial_focus()
        models.WindowManager.toggle_shadows(False)

    def update_overlay(self, target_group=None):
        if target_group is None:
           target_group = self.active_group
        for g in self.groups:
            if g == target_group:
                active_window = g.active_window
                other_windows = [w for w in g.layout.windows if w is not active_window]

                for w in other_windows:
                    w.set_dimmed(True)
                active_window.set_dimmed(False)
            else:
                for w in g.layout.windows:
                    w.set_dimmed(True)

    # def update_overlay(self, target_group=None):
    #     if target_group is None:
    #        target_group = self.active_group
    #     for g in self.groups:
    #         ov = g.overlay
    #         ov.clear()
    #         if g == target_group:
    #             active_window = g.active_window
    #             windows = [w for w in g.layout.windows if w is not active_window]
    #             for w in windows:
    #                 ov.addBorder_(w.frame)
    #             ov.addActiveBorder_(active_window.frame)
    #         else:
    #             for w in g.layout.windows:
    #                 ov.addBorder_(w.frame)

    @notification_receiver
    def newWindow_(self, window):
        if window.space == self.active_space:
            if window.subrole == "AXStandardWindow":
                window.hide_lion_fullscreen_button()
                self.active_group.layout.add_window(window)
            # self.active_group.overlay.flashMessage_("New window")

    @notification_receiver
    def windowDestroyed_(self, window):
        for g in self.groups:
            if g.layout.contains(window):
                g.layout.remove_window(window)
                # self.active_group.overlay.flashMessage_("Window destroyed")

    @notification_receiver
    def windowFocusedExternal_(self, focused_window):
        for g in self.groups:
            if g.layout.contains(focused_window):
                g.layout.focus_window(focused_window)
                self.active_group = g
                self.update_overlay()

    @notification_receiver
    def layoutChanged_(self, _):
        self.update_overlay()

    @notification_receiver
    def newApp_(self, app):
        scripted_app = osax.ScriptingAddition("QSX", pid=app.pid)
        scripted_app.injectQSX()
        self.injected_apps.append(app)
        app.hide_menu_and_dock(True)

        for w in app.windows:
            if w.space == self.active_space:
                if w.subrole == "AXStandardWindow":
                    w.hide_lion_fullscreen_button()
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

    def switch_window_to_group(self, window, groupA, groupB):
        if len(groupA) < 2:
            return
        groupA.layout.remove_window(window)
        groupB.layout.add_window(window)
        # TODO: calling second focus later is a "cheap" solution, not guaranteed to work
        def focus_new_group():
            groupB.layout.focus_window(window)
            self.active_group = groupB
        callLater(0.3, focus_new_group)

    def toNextGroup_(self, sender):
        groupA = self.active_group
        idx = (self.groups.index(groupA) + 1) % len(self.groups)
        groupB = self.groups[idx]
        if groupA == groupB:
            return
        window = self.active_group.active_window
        self.switch_window_to_group(window, groupA, groupB)

    def toPreviousGroup_(self, sender):
        groupA = self.active_group
        idx = (self.groups.index(groupA) - 1)% len(self.groups)
        groupB = self.groups[idx]
        if groupA == groupB:
            return
        window = self.active_group.active_window
        self.switch_window_to_group(window, groupA, groupB)

    def clientToPrevious_(self, sender):
        self.active_group.layout.cmd_client_to_previous()

    def clientToNext_(self, sender):
        self.active_group.layout.cmd_client_to_next()

    def terminate(self):
        models.WindowManager.toggle_shadows(True)

        for g in self.groups:
            for w in g.layout.windows:
                w.set_static(False)
                w.hide_lion_fullscreen_button()

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
