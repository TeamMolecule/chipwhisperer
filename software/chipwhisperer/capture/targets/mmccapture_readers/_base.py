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

from chipwhisperer.common.utils import util
from chipwhisperer.common.utils.pluginmanager import Plugin
from chipwhisperer.common.utils.parameter import Parameterized, Parameter
import logging
import struct
from enum import Enum

class MMCPacket:
    TYPE_REQ = "==>"
    TYPE_RSP = "<=="

    class Cmd(Enum):
        GO_IDLE_STATE = 0
        SEND_OP_COND = 1
        ALL_SEND_CID = 2
        SET_RELATIVE_ADDR = 3
        SET_DSR = 4
        SLEEP_AWAKE = 5
        SWITCH = 6
        SELECT_OR_DESELECT_CARD = 7
        SEND_EXT_CSD = 8
        SEND_CSD = 9
        SEND_CID = 10
        CMD11 = 11
        STOP_TRANSMISSION = 12
        SEND_STATUS = 13
        BUSTEST_R = 14
        GO_INACTIVE_STATE = 15
        SET_BLOCKLEN = 16
        READ_SINGLE_BLOCK = 17
        READ_MULTIPLE_BLOCK = 18
        BUSTEST_W = 19
        CMD20 = 20
        SEND_TUNING_BLOCK = 21
        CMD22 = 22
        SET_BLOCK_COUNT = 23
        WRITE_BLOCK = 24
        WRITE_MULTIPLE_BLOCK = 25
        PROGRAM_CID = 26
        PROGRAM_CSD = 27
        SET_WRITE_PROT = 28
        CLR_WRITE_PROT = 29
        SEND_WRITE_PROT = 30
        SEND_WRITE_PROT_TYPE = 31
        CMD32 = 32
        CMD33 = 33
        CMD34 = 34
        ERASE_GROUP_START = 35
        ERASE_GROUP_END = 36
        CMD37 = 37
        ERASE = 38
        FAST_IO = 39
        GO_IRQ_STATE = 40
        CMD41 = 41
        LOCK_UNLOCK = 42
        CMD43 = 43
        CMD44 = 44
        CMD45 = 45
        CMD46 = 46
        CMD47 = 47
        CMD48 = 48
        SET_TIME = 49
        CMD50 = 50
        CMD51 = 51
        CMD52 = 52
        PROTOCOL_RD = 53
        PROTOCOL_WR = 54
        APP_CMD = 55
        GEN_CMD = 56
        CMD57 = 57
        CMD58 = 58
        CMD59 = 59
        CMD60 = 60
        CMD61 = 61
        CMD62 = 62
        CMD63 = 63

    def __init__(self, raw, count):
        self.crc7 = (raw >> 1) & 0x7F
        self.content = (raw >> 8) & 0xFFFFFFFF
        self.cmd = MMCPacket.Cmd((raw >> 40) & 0x3F)
        self.is_req = (raw >> 46) & 0x1
        self.type = MMCPacket.TYPE_REQ if self.is_req else MMCPacket.TYPE_RSP
        self.count = count

    def __str__(self):
        return '{} [+{:.4f}us] {}, content=0x{:X}, crc7=0x{:X}'.format(self.type, self.count / 52.0, self.cmd, self.content, self.crc7)

class MMCCaptureTemplate(Parameterized, Plugin):

    """
    MMC capture reader base class.

    Note that child classes should only need to implement the following:
    - hw_read()
    - hw_count()
    """

    _name= 'MMC Capture Reader'

    def __init__(self):
        self.connectStatus = util.Observable(False)
        self.getParams()

    def selectionChanged(self):
        pass

    def close(self):
        pass

    def con(self, scope=None):
        """Connect to target"""
        self.connectStatus.setValue(True)

    def dis(self):
        """Disconnect from target"""
        self.close()
        self.connectStatus.setValue(False)

    def count(self):
        return self.hardware_count()

    def read(self):
        data = self.hardware_read()
        data = data[0:6] + b'\x00\x00' + data[6:]
        raw, count = struct.unpack('<QI', data)
        return MMCPacket(raw, count)

    def hardware_count(self):
        """
        Check how many bytes are in waiting on the device's hardware buffer.

        This function needs to be implemented in child classes.

        Returns:
            int: number of bytes waiting to be read
        """
        raise NotImplementedError

    def hardware_read(self):
        """
        Read a captured packet.

        This function needs to be implemented in child classes.

        Returns:
            list: List of read bytes
        """
        raise NotImplementedError
