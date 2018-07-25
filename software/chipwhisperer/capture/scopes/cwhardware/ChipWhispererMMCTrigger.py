#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2014, NewAE Technology Inc
# All rights reserved.
#
# Authors: Colin O'Flynn
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

from chipwhisperer.common.utils.parameter import Parameter, Parameterized, setupSetParam
from chipwhisperer.capture.targets.mmccapture_readers._base import MMCPacket
import logging

CODE_READ       = 0x80
CODE_WRITE      = 0xC0

ADDR_MMCTRIGCFG = 63

class ChipWhispererMMCTrigger(Parameterized):
    """
    Communicates and drives with the MMC trigger module inside the FPGA. 
    """
    _name = 'MMC Trigger Module'
    def __init__(self, oa):
        self.oa = oa

        self.getParams().addChildren([
            {'name':'Match Index', 'type':'bool', 'set':self.setMatchCmd, 'get':self.matchCmd, 'help':"Match the index field with the selected option."},
            {'name':'Cmd Index', 'type': 'list', 'values': {x.name:x.value for x in MMCPacket.Cmd}, 'get':self.cmdIndex, 'set':self.setCmdIndex, 'help':"Only used if Match Index is selected."},
            {'name':'Direction', 'type': 'list', 'values': {'Both': 0, 'Response Only': 1, 'Command Only':2}, 'get':self.direction, 'set':self.setDirection, 'help':"Command is sent from host to device, response is sent from device to host."},
            {'name':'Data Compare', 'type': 'list', 'values': {'Disabled': 0, 'Equals': 1, 'Not Equals':2, 'Less Than':3, 'Greater Than':4}, 'get':self.dataCompareOp, 'set':self.setDataCompareOp, 'help':"Compares the data field to the specified value using the specified operator."},
            {'name':'Data', 'type':'str', 'get':self.triggerData, 'set':self.setTriggerData, 'help':"Only used if Data Compare is not disabled. Can be decimal or hexadecimal prefixed with 0x. 32-bits."},
            {'name':'Trigger on successive cmd', 'type':'bool', 'set':self.setTriggerNext, 'get':self.triggerNext, 'help':"If set, will trigger on the NEXT cmd after the current packet matches other conditions. Useful for triggering on a SEND_STATUS after READ_SINGLE_BLOCK for example."},
        ])

    def matchCmd(self):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        return (data[0] & 0x02) == 0x02

    @setupSetParam("Match Index")
    def setMatchCmd(self, match):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        data[0] = (data[0] & ~0x02) | (match << 1)
        self.oa.sendMessage(CODE_WRITE, ADDR_MMCTRIGCFG, data)

    def cmdIndex(self):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        return data[3] & 0x3F

    @setupSetParam("Cmd Index")
    def setCmdIndex(self, idx):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        data[3] = (data[3] & ~0x3F) | idx
        self.oa.sendMessage(CODE_WRITE, ADDR_MMCTRIGCFG, data)

    def direction(self):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        cmp_trans_en = data[0] & 0x1
        trans = (data[3] & 0x40) == 0x40
        return 1 + trans if cmp_trans_en else 0

    @setupSetParam("Direction")
    def setDirection(self, direction):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        cmp_trans_en = direction > 0
        trans = direction - 1 if cmp_trans_en else 0
        data[0] = (data[0] & ~0x01) | (cmp_trans_en << 0)
        data[3] = (data[3] & ~0x40) | (trans << 6)
        self.oa.sendMessage(CODE_WRITE, ADDR_MMCTRIGCFG, data)

    def dataCompareOp(self):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        cmp_data_en = (data[0] & 0x04) == 0x04
        cmp_data_op = (data[0] & 0x30) >> 4
        return 1 + cmp_data_op if cmp_data_en else 0

    @setupSetParam("Data Compare")
    def setDataCompareOp(self, op):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        cmp_data_en = op > 0
        cmp_data_op = op - 1 if cmp_data_en else 0
        data[0] = (data[0] & ~0x04) | (cmp_data_en << 2)
        data[0] = (data[0] & ~0x30) | (cmp_data_op << 4)
        self.oa.sendMessage(CODE_WRITE, ADDR_MMCTRIGCFG, data)

    def triggerData(self):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, maxResp=8)
        raw = data[4]
        raw |= data[5] << 8
        raw |= data[6] << 16
        raw |= data[7] << 24
        return hex(raw)

    @setupSetParam("Data")
    def setTriggerData(self, num):
        raw = int(num, 0)
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        data[4] = ((raw >> 0) & 0xFF)
        data[5] = ((raw >> 8) & 0xFF)
        data[6] = ((raw >> 16) & 0xFF)
        data[7] = ((raw >> 24) & 0xFF)
        self.oa.sendMessage(CODE_WRITE, ADDR_MMCTRIGCFG, data)

    def triggerNext(self):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        return (data[0] & 0x08) == 0x08

    @setupSetParam("Trigger on successive cmd")
    def setTriggerNext(self, succ):
        data = self.oa.sendMessage(CODE_READ, ADDR_MMCTRIGCFG, Validate=False, maxResp=8)
        data[0] = (data[0] & ~0x08) | (succ << 3)
        self.oa.sendMessage(CODE_WRITE, ADDR_MMCTRIGCFG, data)
