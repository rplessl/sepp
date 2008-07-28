#!/bin/bash
echo create SEPP OS detection file /tmp/SEPP.OS.DETECTOR

# run seppadm environement which runs the OS detection of
# SEPP::OSDetector and creates the file in the /tmp
/usr/sepp/sbin/seppadm environment test-1.0-rp > /dev/null

