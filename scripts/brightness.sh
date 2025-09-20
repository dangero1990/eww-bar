#!/usr/bin/env bash
udevadm monitor --subsystem-match=backlight |
while read -r; do
  brightnessctl -m | awk -F, '{gsub("%","",$4); print $4}'
done
