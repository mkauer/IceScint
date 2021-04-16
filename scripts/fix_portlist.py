#!/usr/bin/python
'''
Converts one-line, unnamed port declarations from previous dev to a more appropriate format.
'''
import sys

orig = sys.stdin.read().replace('\r', '')

decl, rest = orig.split('(', maxsplit=1)
portlist, end = rest.rsplit(')', maxsplit=1)
*ports, port_last = portlist.split(',')

print(decl.strip() + '(')
for port in ports:
    print('\t\t' + port.strip() + ',')
print('\t\t' + port_last.strip())
print('\t)' + end.strip())
