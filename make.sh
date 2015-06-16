#!/bin/bash

astyle --style=ansi --indent=force-tab src/*.d >> /dev/null
rm src/*.orig >> /dev/null
dmd src/*.d -ofv8mud
rm *.o
