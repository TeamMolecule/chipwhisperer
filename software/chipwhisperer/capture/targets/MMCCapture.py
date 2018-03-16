#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2013-2014, NewAE Technology Inc
# All rights reserved.
#
# Find this and more at newae.com - this file is part of the chipwhisperer
# project, http://www.assembla.com/spaces/chipwhisperer
#
#    This file is part of chipwhisperer.
#
#    chipwhisperer is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    chipwhisperer is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Lesser General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with chipwhisperer.  If not, see <http://www.gnu.org/licenses/>.
#=================================================
import logging

from usb import USBError

import binascii
from ._base import TargetTemplate
from chipwhisperer.common.utils import pluginmanager
from mmccapture_readers.cwlite import MMCCapture_ChipWhispererLite
from chipwhisperer.common.utils.parameter import setupSetParam
from chipwhisperer.common.utils import util
from collections import OrderedDict


class MMCCapture(TargetTemplate, util.DisableNewAttr):
    _name = "MMC Capture"

    def __init__(self):
        TargetTemplate.__init__(self)

        ser_cons = pluginmanager.getPluginsInDictFromPackage("chipwhisperer.capture.targets.mmccapture_readers", True, False)
        self.mmc = ser_cons[MMCCapture_ChipWhispererLite._name]
        self.params.addChildren([
            {'name':'Connection', 'type':'list', 'key':'con', 'values':ser_cons, 'get':self.getConnection, 'set':self.setConnection}
        ])

        self.setConnection(self.mmc, blockSignal=True)
        self.disable_newattr()

    def getConnection(self):
        return self.mmc

    @setupSetParam("Connection")
    def setConnection(self, con):
        self.mmc = con
        self.params.append(self.mmc.getParams())

        self.mmc.connectStatus.setValue(False)
        self.mmc.connectStatus.connect(self.connectStatus.emit)
        self.mmc.selectionChanged()

    def _con(self, scope = None):
        if not scope or not hasattr(scope, "qtadc"): Warning("You need a scope with OpenADC connected to use this Target")

        self.mmc.con(scope)

    def close(self):
        if self.mmc != None:
            self.mmc.close()
