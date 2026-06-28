#!/bin/bash
paused=$(dunstctl is-paused)
if [ "$paused" = "true" ]; then
    echo "󰂛"
else
    echo "󰂚"
fi
