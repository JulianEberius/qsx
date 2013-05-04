import os
import objc
from Foundation import NSClassFromString
from AppKit import NSBundle, NSAlternateKeyMask, NSCommandKeyMask,\
    NSControlKeyMask, NSFunctionKeyMask, NSShiftKeyMask, NSDeviceIndependentModifierFlagsMask,\
    NSEvent

GLOBAL_HANDLERS = {}

mod_map = {
    "alt": NSAlternateKeyMask,
    "cmd": NSCommandKeyMask,
    "command": NSCommandKeyMask,
    "control": NSControlKeyMask,
    "ctrl": NSControlKeyMask,
    "shift": NSShiftKeyMask
}
key_map = {
    "left": 123,
    "right": 124,
    "down": 125,
    "up": 126,
    'help': 114, 'mute': 74, 'comma': 43, 'volumedown': 73, '1': 18, '0': 29, '4': 21, '8': 28, 'return': 36, 'enter': 36, 'slash': 44, 'downarrow': 125, 'd': 2, 'h': 4, 'l': 37, 'p': 35, 't': 17, 'x': 7, 'forwarddelete': 117, 'rightbracket': 30, 'right': 124, 'escape': 53, 'home': 115, '5': 23, 'space': 49, '3': 20, 'f20': 90, 'pagedown': 121, '7': 26, 'keypadequals': 81, 'keypadplus': 69, 'c': 8, 'f11': 103, 'keypadclear': 71, 'g': 5, 'k': 40, 'equal': 24, 'o': 31, 'minus': 27, 's': 1, 'w': 13, 'f15': 113, 'rightshift': 60, 'period': 47, 'down': 125, 'capslock': 57, 'f6': 97, '2': 19, 'keypadmultiply': 67, '6': 22, 'function': 63, 'option': 58, 'leftbracket': 33, 'f19': 80, 'b': 11, 'f': 3, 'j': 38, 'pageup': 116, 'up': 126, 'n': 45, 'f18': 79, 'r': 15, 'rightoption': 61, 'v': 9, 'f12': 111, 'f13': 105, 'f10': 109, 'z': 6, 'f16': 106, 'f17': 64, 'f14': 107, 'delete': 51, 'f1': 122, 'f2': 120, 'f3': 99, 'f4': 118, 'f5': 96, 'semicolon': 41, 'f7': 98, 'f8': 100, 'f9': 101, 'backslash': 42, 'keypaddivide': 75, 'tab': 48, 'rightarrow': 124, 'end': 119, 'leftarrow': 123, 'keypad7': 89, 'keypad6': 88, 'keypad5': 87, 'keypad4': 86, 'keypad3': 85, 'keypad2': 84, 'keypad1': 83, 'keypad0': 82, '9': 25, 'u': 32, 'keypad9': 92, 'keypad8': 91, 'quote': 39, 'volumeup': 72, 'grave': 50, '<': 50, '>':62, 'keypaddecimal': 65, 'e': 14, 'i': 34, 'keypadminus': 78, 'm': 46, 'uparrow': 126, 'q': 12, 'y': 16, 'keypadenter': 76, 'left': 123
}


# this module contains a wrapper around the SGHotKeysLib to make it usable from Python/PyObjC
base_path = os.path.join(
    NSBundle.mainBundle().bundlePath(), "Contents", "Frameworks")
bundle_path = os.path.abspath(os.path.join(base_path, 'SGHotKey.framework'))
objc.loadBundle(
    'SGHotKey', globals(), bundle_path=objc.pathForFramework(bundle_path))

SGHotKey = NSClassFromString("SGHotKey")
SGKeyCombo = NSClassFromString("SGKeyCombo")
SGHotKeyCenter = NSClassFromString("SGHotKeyCenter")

cmdKeyBit = 8
shiftKeyBit = 9
optionKeyBit = 11
controlKeyBit = 12

cmdKey = 1 << cmdKeyBit
shiftKey = 1 << shiftKeyBit
optionKey = 1 << optionKeyBit
controlKey = 1 << controlKeyBit


def cocoa_to_carbon_flags(cocoa_flags):
    carbon_flags = 0

    if cocoa_flags & NSCommandKeyMask:
        carbon_flags |= cmdKey
    if cocoa_flags & NSAlternateKeyMask:
        carbon_flags |= optionKey
    if cocoa_flags & NSControlKeyMask:
        carbon_flags |= controlKey
    if cocoa_flags & NSShiftKeyMask:
        carbon_flags |= shiftKey
    if cocoa_flags & NSFunctionKeyMask:
        carbon_flags |= NSFunctionKeyMask

    return carbon_flags

def register_key_from_string(key_str, target, signal):
    elems = key_str.split("+")
    modifiers = 0
    keycode = -1
    for e in elems:
        if e in mod_map:
            modifiers |= mod_map[e]
        elif e in key_map:
            keycode = key_map[e]

    combo = SGKeyCombo.keyComboWithKeyCode_modifiers_(keycode,
        cocoa_to_carbon_flags(modifiers))
    hotkey = SGHotKey.alloc().initWithIdentifier_keyCombo_target_action_(
            signal, combo, target, signal)
    SGHotKeyCenter.sharedCenter().registerHotKey_(hotkey)

    return hotkey

def install_global_handler(_id, handler, event_mask, key_mask=None):
    def key_handler(ev):
        if (ev.modifierFlags() & NSDeviceIndependentModifierFlagsMask) == key_mask:
            handler(ev)

    def simple_handler(ev):
        handler(ev)

    if not _id:
        _id = str(handler) + str(event_mask) + str(key_mask)
    obs = NSEvent.addGlobalMonitorForEventsMatchingMask_handler_(
        event_mask, key_handler if key_mask else simple_handler)
    GLOBAL_HANDLERS[_id] = obs

def remove_global_handler(_id):
    obs = GLOBAL_HANDLERS.pop(_id, None)
    if obs:
        NSEvent.removeMonitor_(obs)

def init_default_qsx_hotkeys(caller):
    register_key_from_string("alt+ctrl+j", caller, "down:")
    register_key_from_string("alt+ctrl+k", caller, "up:")
    # register_key_from_string("alt+ctrl+h", caller, "previous:")
    # register_key_from_string("alt+ctrl+l", caller, "next:")
    # register_key_from_string("cmd+alt+ctrl+h", caller, "clientToPrevious:")
    # register_key_from_string("cmd+alt+ctrl+l", caller, "clientToNext:")
    register_key_from_string("alt+ctrl+l", caller, "shuffleDown:")
    register_key_from_string("alt+ctrl+h", caller, "shuffleUp:")

    register_key_from_string("alt+ctrl+g", caller, "grow:")
    register_key_from_string("alt+ctrl+s", caller, "shrink:")
    register_key_from_string("alt+ctrl+n", caller, "normalize:")
    register_key_from_string("alt+ctrl+m", caller, "maximize:")

    register_key_from_string("alt+ctrl+f", caller, "flip:")

def init_default_delegate_hotkeys(caller):
    #quit and gogogo shortcut
    register_key_from_string("cmd+alt+ctrl+q", caller, "exit:")
    register_key_from_string("cmd+alt+ctrl+r", caller, "doStuff:")
    register_key_from_string("cmd+alt+ctrl+t", caller, "someTest:")

