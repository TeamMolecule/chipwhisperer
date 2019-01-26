#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2013-2014, NewAE Technology Inc
# All rights reserved.
#
# Author: Colin O'Flynn
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
import numpy as np
import os.path
from ._base import PreprocessingBase
from chipwhisperer.common.api import CWCoreAPI
from chipwhisperer.common.utils.parameter import setupSetParam

class Reject(PreprocessingBase):
    """
    Rejects any sample with value < something 
    """
    _name = "Reject"
    _cutoff = float('-inf')
    _idx_map = []
    _count = 0

    def __init__(self, traceSource=None, name=None):
        PreprocessingBase.__init__(self, traceSource, name=name)
        self.getParams().addChildren([
            {'name':'Cutoff', 'key':'cutoff', 'type':'float', 'get':self._getCutoff, 'set':self._setCutoff},
        ])
        self._trace_cache_file = CWCoreAPI.CWCoreAPI.getInstance().project().getDataFilepath("tempcache.npy")['abs']

    def processTraces(self):
        if os.path.isfile(self._trace_cache_file):
            fmode = "r+"
        else:
            fmode = "w+"
        self._trace_cache = np.memmap(self._trace_cache_file, dtype="float32", mode=fmode, shape=(self._traceSource.numTraces(), self._traceSource.numPoints()))
        self._idx_map = []
        self._count = 0
        last = self._traceSource.numTraces()
        for i in range(last):
            trace = self._traceSource.getTrace(i)
            if np.min(trace) >= self._cutoff:
                self._trace_cache[self._count] = trace
                self._idx_map.append(i)
                self._count += 1

    def getTrace(self, n):
        if self.enabled:
            return self._trace_cache[n]
        else:
            return self._traceSource.getTrace(n)

    def getTextin(self, n):
        if self.enabled:
            return self._traceSource.getTextin(self._idx_map[n])
        else:
            return self._traceSource.getTextin(n)

    def getTextout(self, n):
        if self.enabled:
            return self._traceSource.getTextout(self._idx_map[n])
        else:
            return self._traceSource.getTextout(n)

    def getKnownKey(self, n=None):
        if self.enabled:
            return self._traceSource.getKnownKey(self._idx_map[n])
        else:
            return self._traceSource.getKnownKey(n)

    def numTraces(self):
        if self.enabled:
            return self._count
        else:
            return self._traceSource.numTraces()

    def _getCutoff(self):
        return self._cutoff

    @setupSetParam("Cutoff")
    def _setCutoff(self, cutoff):
        self._cutoff = cutoff
        if cutoff > float('-inf'):
          self.processTraces()

