from layouts.xmonad import MonadTall
from layouts.stack import Stack
from utils import notify
from models import WindowManager
from PyObjCTools.AppHelper import callLater

class QTileGroupAdapter(object):
    """simulates QTile's Group object (=workspace)"""
    class QTileScreen(object):
        def __init__(self, x, y, w, h):
            self.x = x
            self.y = y
            self.width = w
            self.height = h
        @property
        def dwidth(self):
            return self.width
        @property
        def dheight(self):
            return self.height
        @property
        def dx(self):
            return self.x
        @property
        def dy(self):
            return self.y

    class QTileRootAdapter(object):
        def __init__(self):
            pass
        def colorPixel(self, name):
            pass

    def __init__(self, layout, screen, overlay):
        self.layout = layout
        self.layout.group = self
        screen_frame = screen.frame();
        self.screen = QTileGroupAdapter.QTileScreen(
            screen_frame.origin.x,
            WindowManager.real_y(screen),
            screen_frame.size.width,
            screen_frame.size.height)
        self.qtile = QTileGroupAdapter.QTileRootAdapter()
        self.overlay = overlay
        self.overlay.retain()
        self.current_window = None

    def __len__(self):
        return len(self.layout.windows)

    # @property
    # def screen(self):
    #     s = screen_size()
    #     return QTileGroupAdapter.QTileScreen(0, 0, s.width, s.height)

    def layoutAll(self):
        self.layout.apply()

    @property
    def active_window(self):
        return self.layout.focus_first()

    def set_initial_focus(self):
        self.focus(self.active_window, False)

    def focus(self, window, warp):
        # focusing the window on OS level will trigger an update throughout QSX
        window.focus()

class Layout(object):
    """Represents a possible layout of windows on a screen"""
    def __init__(self, windows):
        self.windows = windows
        return self

    def window_at_position(self, x, y):
        for w in self.windows:
            if x >= w.x and y >= w.y and x <= w.x + w.width and y <= w.y + w.height:
                return w
        return None

class QTileLayoutWrapper(Layout):

    def __init__(self, windows, qtile_layout):
        self = Layout.__init__(self, windows)
        self.qtile_layout = qtile_layout
        for w in self.windows:
            self.qtile_layout.add(w)
            w.layout = self
        return self

    @property
    def group(self):
        return self.qtile_layout.group

    @group.setter
    def group(self, value):
        self.qtile_layout.group = value

    def size_of_window(self, window):
        '''returns the size of the slot the window is in in screen
        coordinates'''
        return (window.x, window.y, window.width, window.height)

    def contains(self, window):
        for w in self.windows:
            if w == window:
                return True
        return False

    def apply(self):
        for w in self.windows:
            w.set_static(True)
        self.qtile_layout.layout(self.windows, self.qtile_layout.group.screen)
        notify("QSXLayoutChanged", self)

    @property
    def active_window(self):
        return self.qtile_layout.group.current_window

    def add_window(self, new_window):
        # Some apps change their state on new window, force them back
        new_window.set_static(True)
        new_window.app.hide_menu_and_dock(True)

        new_window.layout = self
        self.windows.append(new_window)
        self.qtile_layout.add(new_window)
        self.qtile_layout.focus(new_window)
        self.group.focus(new_window, False)


    def remove_window(self, window):
        self.windows.remove(window)
        self.qtile_layout.remove(window)

        next_focus = self.qtile_layout.focus_first()
        self.qtile_layout.focus(next_focus)

    def focus_first(self):
        return self.qtile_layout.focus_first()

    def set_focused_window(self, window):
        ''' has to be implemented on subclasses, as the specific
        state of the respective layouts has to be changed.
        the existing layout API will also trigger a re-layout '''
        pass

    def focus_window(self, window):
        self.qtile_layout.focus(window)

    def __getattr__(self, attr):
        ''' deletegate qtile commands to the qtile layout'''
        if attr.startswith("cmd_"):
            return getattr(self.qtile_layout, attr)

class StackLayout(QTileLayoutWrapper):

    def __init__(self, windows):
        stack = Stack()
        stack.border_width = 0
        QTileLayoutWrapper.__init__(self, windows, stack)
        self.qtile_layout.nextStack()

class XMonadLayout(QTileLayoutWrapper):

    def __init__(self, windows):
        xmonad = MonadTall()
        xmonad.border_width = 0
        QTileLayoutWrapper.__init__(self, windows, xmonad)
