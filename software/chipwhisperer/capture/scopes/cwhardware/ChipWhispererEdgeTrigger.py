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
from functools import partial
import logging

CODE_READ       = 0x80
CODE_WRITE      = 0xC0

ADDR_EDGETRIGCFG = 50

class ChipWhispererEdgeTrigger(Parameterized):
    PIN_RTIO1 = (1 << 0)
    PIN_RTIO2 = (1 << 1)
    PIN_RTIO3 = (1 << 2)
    PIN_RTIO4 = (1 << 3)
    PIN_HS1 = (1 << 4)
    PIN_HS2 = (1 << 5)
    PIN_SCK = (1 << 6)
    PIN_MOSI = (1 << 7)
    PIN_MISO = (1 << 8)
    PIN_NRST = (1 << 9)
    PIN_PDIC = (1 << 10)
    PIN_PDID = (1 << 11)
    MODE_OR = 0x00
    MODE_AND = 0x01
    MODE_NAND = 0x02
    EDGE_RISING = 0x0
    EDGE_FALLING = 0x1
    EDGE_BOTH = 0x2

    """
    Communicates and drives with the edge trigger module inside the FPGA. 
    """
    _name = 'Edge Trigger Module'
    def __init__(self, oa):
        self.oa = oa

        self.getParams().addChildren([
            {'name': 'Trigger Pins', 'type':'group', 'children':[
                {'name': 'Target IO1 (Serial TXD)', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_RTIO1), 'set':partial(self.setPin, pin=self.PIN_RTIO1)},
                {'name': 'Target IO2 (Serial RXD)', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_RTIO2), 'set':partial(self.setPin, pin=self.PIN_RTIO2)},
                {'name': 'Target IO3 (SmartCard Serial)', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_RTIO3), 'set':partial(self.setPin, pin=self.PIN_RTIO3)},
                {'name': 'Target IO4 (Trigger Line)', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_RTIO4), 'set':partial(self.setPin, pin=self.PIN_RTIO4)},
                {'name': 'Target HS1', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_HS1), 'set':partial(self.setPin, pin=self.PIN_HS1)},
                {'name': 'Target HS2', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_HS2), 'set':partial(self.setPin, pin=self.PIN_HS2)},
                {'name': 'Target SCK', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_SCK), 'set':partial(self.setPin, pin=self.PIN_SCK)},
                {'name': 'Target MOSI', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_MOSI), 'set':partial(self.setPin, pin=self.PIN_MOSI)},
                {'name': 'Target MISO', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_MISO), 'set':partial(self.setPin, pin=self.PIN_MISO)},
                {'name': 'Target nRST', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_NRST), 'set':partial(self.setPin, pin=self.PIN_NRST)},
                {'name': 'Target PDIC', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_PDIC), 'set':partial(self.setPin, pin=self.PIN_PDIC)},
                {'name': 'Target PDID', 'type':'bool', 'get':partial(self.getPin, pin=self.PIN_PDID), 'set':partial(self.setPin, pin=self.PIN_PDID)},
            ]},
            {'name': 'Collection Mode', 'type':'list', 'values':{"OR":self.MODE_OR, "AND":self.MODE_AND, "NAND":self.MODE_NAND}, 'get':self.getPinMode, 'set':self.setPinMode},
            {'name': 'Trigger Edge', 'type':'list', 'values':{"Rising Only":self.EDGE_RISING, "Falling Only":self.EDGE_FALLING, "Both Edges":self.EDGE_BOTH}, 'get':self.edgeStyle, 'set':self.setEdgeStyle},
            {'name': 'Times Seen', 'type':'int', 'limits':(1, 63), 'set':self.setFilter, 'get':self.filter,
             'help': '%namehdr%'+
                        'See edge X times before triggering.'},
        ])

    @setupSetParam("")
    def setPin(self, enabled, pin):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        pins = (resp[1] << 8) | resp[0]
        pins = (pins & ~pin) | (pin if enabled else 0)
        resp[1] = pins >> 8
        resp[0] = pins & 0xFF
        self.oa.sendMessage(CODE_WRITE, ADDR_EDGETRIGCFG, resp)

    def getPin(self, pin):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        pins = (resp[1] << 8) | resp[0]
        current = pins & pin
        if current == 0:
            return False
        else:
            return True

    @setupSetParam("Collection Mode")
    def setPinMode(self, mode):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        resp[2] = (resp[2] & ~3) | mode
        self.oa.sendMessage(CODE_WRITE, ADDR_EDGETRIGCFG, resp)

    def getPinMode(self):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        return resp[2] & 0x3

    @setupSetParam("Trigger Edge")
    def setEdgeStyle(self, style):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        resp[2] = (resp[2] & ~0xC) | (style << 2)
        self.oa.sendMessage(CODE_WRITE, ADDR_EDGETRIGCFG, resp)

    def edgeStyle(self):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        return (resp[2] >> 2) & 0x3

    @setupSetParam("Times Seen")
    def setFilter(self, count):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        resp[2] = (resp[2] & ~0xF0) | ((count & 0xF) << 4)
        resp[3] = (resp[3] & ~0x03) | (count >> 4)
        self.oa.sendMessage(CODE_WRITE, ADDR_EDGETRIGCFG, resp)

    def filter(self):
        resp = self.oa.sendMessage(CODE_READ, ADDR_EDGETRIGCFG, Validate=False, maxResp=4)
        return ((resp[2] & 0xF0) >> 4) | ((resp[3] & 0x03) << 4)
