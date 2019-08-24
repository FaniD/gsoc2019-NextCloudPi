#!/usr/bin/env python3

import subprocess, re

jobs = subprocess.check_output("travis show")
#jobs = commands.getoutput('travis show')
#jobs = map(lambda x: x.split(), jobs.split('\n'))
print (jobs)
