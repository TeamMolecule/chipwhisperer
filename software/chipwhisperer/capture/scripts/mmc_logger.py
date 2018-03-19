"""Logs MMC read/write traffic to terminal
"""

import chipwhisperer as cw
import logging
from chipwhisperer.capture.targets.MMCCapture import MMCCapture

scope = cw.scope()
target = cw.target(scope, MMCCapture)
mmc = target.mmc

while True:
    try:
        pavail = mmc.count()
    except IOError, e:
        logging.error("IOError in read (%s)"%str(e))
        break

    if pavail > 0:
        data = mmc.read()
        print str(data)

scope.dis()
target.dis()
