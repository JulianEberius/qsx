#
#  main.py
#  AweSX
#
#  Created by Julian Eberius on 09.03.10.
#  Copyright __MyCompanyName__ 2010. All rights reserved.
#

#import modules required by application
import objc
import Foundation
import AppKit

from PyObjCTools import AppHelper

# import modules containing classes required to start application and load MainMenu.nib
import app_delegate

# pass control to AppKit
AppHelper.runEventLoop()
