#!/bin/sh

echo 'Parsing ZMK keymap...'
keymap -c chocofi_keymap_config.yaml parse -c 10 -z ../config/chocofi.keymap > chocofi_keymap.yaml

echo '\n\nAdjusting keymap yaml...'
./keymap_img_adjuster.py chocofi_keymap.yaml

echo '\n\nDrawing keymap...'
keymap -c chocofi_keymap_config.yaml draw -k chocofi chocofi_keymap.yaml > chocofi_keymap.svg
