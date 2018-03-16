#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2014, NewAE Technology Inc
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

import sys
from PySide.QtCore import *
from PySide.QtGui import *
import chipwhisperer.common.utils.qt_tweaks as QtFixes
import logging


class MMCCaptureDialog(QtFixes.QDialog):
    def __init__(self, parent, cwAPI):
        super(MMCCaptureDialog, self).__init__(parent)
        self.cwAPI = cwAPI
        self.mainLayout = QVBoxLayout()

        ### Layout for text boxes
        self.textLayouts = QGridLayout()

        self.textOut = QTextEdit()

        self.textClear = QPushButton("Clear")
        self.textClear.clicked.connect(self.textOut.clear)

        # 3 = rowSpan
        self.textLayouts.addWidget(self.textOut, 0, 0)
        self.textLayouts.addWidget(self.textClear, 0, 1)

        self.textOut.setReadOnly(True)

        ### Layout for line end & printing characters
        self.mainLayout.addLayout(self.textLayouts)
        
        hsep = QFrame()
        hsep.setFrameShape(QFrame.HLine)
        self.mainLayout.addWidget(hsep)
        
        ### Layout for connection settings
        self.conLayout = QHBoxLayout()

        self.pollIntervalSP = QSpinBox()
        self.pollIntervalSP.setMinimum(1)
        self.pollIntervalSP.setMaximum(500)
        self.pollIntervalSP.setValue(100)
        self.pollIntervalSP.valueChanged.connect(self.updateTimerInterval)
        
        self.conPB = QPushButton("Connect")
        self.conLayout.addWidget(self.conPB)
        self.conLayout.addWidget(QLabel("Set target in main GUI"))
        self.conLayout.addStretch()
        self.conLayout.addWidget(QLabel("Polling Interval (mS)"))
        self.conLayout.addWidget(self.pollIntervalSP)
        self.conPB.clicked.connect(self.handleConButton)
        self.conPB.setCheckable(True)

        self.mainLayout.addLayout(self.conLayout)

        # ## Final Setup

        self.textOut.setEnabled(False)

        self.setLayout(self.mainLayout)
        self.hide()

        self.timerRead = QTimer()
        self.timerRead.timeout.connect(self.checkRead)

        self.driver = None

    def addTextOut(self, data, color=Qt.black):
        
        cmain = QColor(color)
        self.textOut.moveCursor(QTextCursor.End)
        self.textOut.setTextColor(cmain)
        self.textOut.insertPlainText(data)
        self.textOut.insertPlainText('\n')
        self.textOut.moveCursor(QTextCursor.End)


        self.textOut.setTextColor(QColor(Qt.black))

    def checkRead(self):
        try:
            pavail = self.driver.count()
        except IOError, e:
            logging.error("IOError in read (%s)"%str(e))
            self.tryDis()
            return

        while pavail > 0:
            data = self.driver.read()
            self.addTextOut(data)
            QCoreApplication.processEvents()
            pavail = self.driver.count()

    def handleConButton(self):
        if self.conPB.isChecked():
            self._tryCon()
            self.conPB.setText("Disconnect")
        else:
            self._tryDis()
            self.conPB.setText("Connect")

    def tryCon(self):
        self.conPB.setChecked(True)
        self.handleConButton()

    def _tryCon(self):
        self.driver = self.cwAPI.getTarget().mmc

        self.textOut.setEnabled(True)
        self.pollIntervalSP.setEnabled(True)

        self.timerRead.start(self.pollIntervalSP.value())

    def tryDis(self):
        self.conPB.setChecked(False)
        self.handleConButton()

    def _tryDis(self):
        self.textOut.setEnabled(False)
        self.pollIntervalSP.setEnabled(False)
        self.timerRead.stop()
        
        if self.driver is not None:
            self.driver.dis()
            self.driver = None

    def updateTimerInterval(self, _=None):
        if self.timerRead.isActive():
            self.timerRead.stop()
            self.timerRead.start(self.pollIntervalSP.value())


    def closeEvent(self, ev):
        self.tryDis()

        QDialog.closeEvent(self, ev)


def main():
    # Create the Qt Application
    app = QApplication(sys.argv)

    std = MMCCaptureDialog(None)
    std.show()

    app.exec_()

if __name__ == '__main__':
    main()
