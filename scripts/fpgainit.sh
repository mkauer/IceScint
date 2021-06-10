#!/bin/bash

REMOTE=taxi105
FILENAME=$(date +%F_%H-%M).bin
FILEPATH=/home/root/daq/firmware/Martin-IO-Registers/$FILENAME

echo Uploading $FILENAME to $REMOTE
scp "../impl/icescint/icescint_io.bit" "$REMOTE:$FILEPATH"
ssh $REMOTE LD_LIBRARY_PATH=/opt/taxi/lib /opt/taxi/bin/fpgainit -f "$FILEPATH"