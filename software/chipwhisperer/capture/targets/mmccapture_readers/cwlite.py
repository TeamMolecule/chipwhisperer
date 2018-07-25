#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2013-2016, NewAE Technology Inc
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

from _base import MMCCaptureTemplate

class MMCCapture_ChipWhispererLite(MMCCaptureTemplate):
    _name = 'NewAE USB (CWLite/CW1200)'
    CODE_READ       = 0x80
    CODE_WRITE      = 0xC0
    ADDR_STATUS     = 0x3B
    ADDR_LEN        = 0x3C
    ADDR_DATA       = 0x3D

    def __init__(self):
        MMCCaptureTemplate.__init__(self)

    def close(self):
        pass

    def con(self, scope = None):
        if not scope or not hasattr(scope, "qtadc"): Warning("You need a scope with OpenADC connected to use this Target")

        self.oa = scope.qtadc.sc
        scope.connectStatus.connect(self.dis)
        # Check first!
        self.params.refreshAllParameters()
        self.connectStatus.setValue(True)

    def hardware_count(self):
        data = self.oa.sendMessage(self.CODE_READ, self.ADDR_STATUS, maxResp=1)
        empty = data[0] & 1
        full = (data[0] >> 1) & 1
        overflow = (data[0] >> 2) & 1
        data = self.oa.sendMessage(self.CODE_READ, self.ADDR_LEN, maxResp=1)
        count = data[0]
        if count == 255 or overflow:
            logging.warning('MMC capture buffer overflow!')
        return 0 if empty else count * 16 if count > 0 else 1

    def hardware_read(self):
        return self.oa.sendMessage(self.CODE_READ, self.ADDR_DATA, maxResp=8)
