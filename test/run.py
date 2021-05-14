#!/usr/bin/python
from vunit import VUnit


# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
vu.add_osvvm()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("src/*.vhd")
lib.add_source_files("../lib/noasic/components/*.vhd")
lib.add_source_files("../src/util/*.vhd")
lib.add_source_files("../src/types/types.vhd")
lib.add_source_files("../src/register_banks/*.vhd")


# Run vunit function
vu.main()