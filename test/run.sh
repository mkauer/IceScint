#!/bin/bash

./run.py "lib.$1.all" --gtkwave-args "-a $(pwd)/vunit_out/test_output/$1.gtkw" --gui