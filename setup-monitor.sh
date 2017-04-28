#!/bin/bash
dvi=DVI-I-1
hdmi=HDMI-3

xrandr --output "$dvi" --auto --primary --output "$hdmi" --auto --left-of "$dvi"
