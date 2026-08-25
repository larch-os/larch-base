#!/bin/bash
grim -g "$(slurp -c '#ff0000ff')" -t ppm - | satty -c ~/.config/satty/config.toml --filename - --output-filename ~/Pictures/Screenshots/satty-$(date '+%Y%m%d-%H:%M:%S').png