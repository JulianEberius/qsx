import subprocess
import json
from contextlib import contextmanager
from os.path import abspath, expanduser, isfile
from math import ceil
from Foundation import NSNotificationCenter
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

SUPRESSED_NOTIFICATIONS = []

@contextmanager
def supress_notification(notification, obj=None):
    tup = (notification, obj)
    SUPRESSED_NOTIFICATIONS.append(tup)
    yield
    SUPRESSED_NOTIFICATIONS.remove(tup)

def notify(msg, sender, user_info=None):
    NSNotificationCenter.defaultCenter().postNotificationName_object_userInfo_(msg, sender, user_info)

def notification_receiver(func):
    ''' Decorated functions will be passed either NSNotifications carrying
    domain objects (Windows etc) or domain objects directly. This decorator
    unwraps the objects from notifications.

    Also checks whether the event is not supressed
    '''
    @wraps(func)
    def decorated_func(self, notification):
        obj = notification.object()
        tup = notification.name(), obj
        if tup in SUPRESSED_NOTIFICATIONS:
            return
        return func(self, obj)

    return decorated_func

'''
Misc
'''

def partition(lst, n):
    partitions = []
    part_size = ceil(len(lst) / float(n))
    for i in xrange(n):
        _from = int(i * part_size)
        _to = int(min((i + 1) * part_size, len(lst)))
        partitions.append(lst[_from:_to])

    return partitions

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
