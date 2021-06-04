# IceScint FPGA Code

## Resources
### IRIG
- https://www.itsamerica.com/assets/publications/TN-102_IRIG-B.pdf
- https://www.meinbergglobal.com/english/info/irig.htm#formats

## TODO
- generate DRS4 refclock without DLLs!!!
- Use IRIG decoder from https://github.com/jkelley/irig-decoder
- implement DNA_POR (Primitive:DeviceDNADataAccessPort) for device ID

## TODO (check with others)
- remove Trigger Timing, DRS4 Sampling, DRS4 Charge, DRS4 Baseline, Pixel Rate Counter, GPS
- add RS485 loopback
- test RS485 enable / rx block