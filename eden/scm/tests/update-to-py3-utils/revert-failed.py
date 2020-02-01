#!/usr/bin/env python3
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

import json
import subprocess


with open("report.json", "r") as f:
    tests = json.load(f)
    for name, t in tests.items():
        name = name.split(" ")[0]
        if t["result"] != "success":
            print("%s not successful" % name)
            subprocess.run("hg revert %s" % name, shell=True)
