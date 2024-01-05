#!/bin/sh

echo 'Parsing ZMK keymap...'
keymap -c keymap_config.yaml parse -c 12 -z ../config/corne.keymap > keymap.yaml

# echo '\n\nAdjusting keymap yaml...'
# ./keymap_img_adjuster.py keymap.yaml

echo '\n\nDrawing keymap...'
keymap -c keymap_config.yaml draw --qmk-keyboard crkbd/rev1 --qmk-layout LAYOUT_split_3x6_3 keymap.yaml -s Base Nav Num Func Sym Adjust > keymap.svg
