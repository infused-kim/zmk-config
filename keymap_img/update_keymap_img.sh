#!/bin/sh

# echo 'Parsing ZMK keymap...'
# keymap -c chocofi_keymap_config.yaml parse -c 10 -z ../config/corne.keymap > chocofi_keymap.yaml
rm -rf chocofi_keymap.yaml && keymap -c chocofi_keymap_config.yaml parse -c 10 -z ../config/chocofi.keymap >chocofi_keymap.yaml

echo '\n\nAdjusting keymap yaml...'
rm -rf chocofi_keymap.yamlupdated && ./keymap_img_adjuster.py chocofi_keymap.yaml

echo '\n\nDrawing keymap...'
keymap -c chocofi_keymap_config.yaml draw -k chocofi chocofi_keymap.yamlupdated >chocofi_keymap.svg
