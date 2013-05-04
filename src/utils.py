import subprocess
import inspect
import json
from os.path import abspath, expanduser, isfile
from Foundation import NSNotification, NSNotificationCenter
from AppKit import NSBundle, NSFileManager
from functools import wraps


'''
Configuration
'''

BORDERLESS_APPS = "enable_borderless_mode_for"
DEBUG = "debug"
# default config
config = {
    BORDERLESS_APPS: [],
    DEBUG: False
}

def load_config():
    config_path = abspath(expanduser("~/.qsx"))
    if isfile(config_path):
        with open(config_path) as conf_file:
            global config
            config = json.load(conf_file)
    else:
        with open(config_path, "w") as conf_file:
            json.dump(config, conf_file, indent=4)


'''
Notifications
'''


def notify(msg, sender, user_info=None):
    NSNotificationCenter.defaultCenter().postNotificationName_object_userInfo_(msg, sender, user_info)

def notification_receiver(func):
    ''' Decorated functions will be passed either NSNotifications carrying
    domain objects (Windows etc) or domain objects directly. This decorator
    unwraps the objects from notifications.

    NOTE: we cannot use one decorator function with *args here, as the
    decorated function will have a variadic number of parameters and will
    not be recognized by PyObjC. We need to return a function with the exact
    same number of parameters. Surely, there is a better solution using magic.
    '''

    @wraps(func)
    def decorated_func_1(a1):
        args = [a.object() if isinstance(a, NSNotification) else a
                    for a in [a1]]
        return func(*args)

    @wraps(func)
    def decorated_func_2(a1, a2):
        args = [a.object() if isinstance(a, NSNotification) else a
                    for a in [a1, a2]]
        return func(*args)

    @wraps(func)
    def decorated_func_3(a1, a2, a3):
        args = [a.object() if isinstance(a, NSNotification) else a
                    for a in [a1, a2, a3]]
        return func(*args)

    return {
        1: decorated_func_1,
        2: decorated_func_2,
        3: decorated_func_3
    }.get(len(inspect.getargspec(func)[0]))

'''
Misc
'''

def resource_path(resource, resource_type):
        path = NSBundle.mainBundle().pathForResource_ofType_(
            resource, resource_type)
        if NSFileManager.defaultManager().fileExistsAtPath_(path):
            return path
        else:
            return None

def get_wallpaper():
    output = subprocess.check_output(
        "osascript -e 'tell application \"Finder\" to get desktop picture'", shell=True)
    return "/" + "/".join(
        reversed(output[14:].strip().replace(" of startup disk","").split(" of folder ")))

def set_wallpaper(path=None):
    if path is None:
        path = resource_path("apple_linen", "jpg")
    subprocess.check_output(
        "osascript -e 'tell application \"Finder\" to set desktop picture to POSIX file \"%s\"'" % path, shell=True)
