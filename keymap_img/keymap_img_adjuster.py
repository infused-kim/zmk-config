#!/usr/bin/env python3

import copy
import argparse
import sys
import oyaml as yaml

# Settings
# To get key numbers, check...
# zmk-nodefree-config/keypos_def/keypos_36keys.h
#
# Increment the numbers from there by 1
pressed_buttons = [
    # ('Nav', 35),
    # ('Sym', 32),
    # ('Num', 36),
    # ('Func', 32),
    # ('Func', 36),
    # ('Adjust', 33),
]

delete_layers = [
    # 'QWERTY',
    # 'Nav Word',
    # 'Sym Word',
    # 'Num Word',
    # 'Lower',
]

combo_locations = {
    # (30, 31, 32): {'a': 'bottom', 'o': 0.3},
    # (2, 3, 4): {'a': 'top', 'o': 0.3},
    # (11, 12, 13): {'a': 'bottom', 'o': -0.25},
    # (21, 22, 23): {'a': 'bottom', 'o': 0.0},
    (13, 16): {'k': "Caps\nWord"},
}


def get_keymap_yaml(file_path):
    with open(file_path, 'r') as f:
        keymap = yaml.safe_load(f)

    return keymap


def write_keymap_yaml(file_path, keymap):
    with open(file_path, 'w') as f:
        yaml.dump(keymap, f)


def adjust_combo(keymap, combo_locations):
    keymap = copy.deepcopy(keymap)

    for combo in keymap['combos']:
        # if len(combo['p']) > 2:
        #     combo['a'] = 'top'

        combo_location = combo_locations.get(tuple(combo['p']), None)
        if combo_location is not None:
            combo.update(combo_location)

    return keymap


def remove_layers(keymap, remove_layers):
    keymap = copy.deepcopy(keymap)

    for layer in remove_layers:
        keymap['layers'].pop(layer, None)

    for combo in keymap['combos']:
        for layer in remove_layers:
            try:
                combo['l'].remove(layer)
            except (ValueError, KeyError):
                pass

    return keymap


def highlight_buttons(keymap, buttons):
    keymap = copy.deepcopy(keymap)

    for button in buttons:
        b_layer = button[0]
        b_num = button[1] - 1

        layer = keymap['layers'].get(b_layer, None)
        if layer is None:
            print(f"Can't highlight button: {button}: Layer not found")
            continue

        # The buttons aren't stored as rows that correspond to the rows on the
        # keyboard. Instead it seems that they are stored in rows of 10 buttons
        # We loop through them until we find the button with the right number.
        b_row = None
        b_index = None
        prev_layer_buttons = 0
        for layer_row in layer:
            if prev_layer_buttons + len(layer_row) > b_num:
                b_row = layer_row
                b_index = b_num - prev_layer_buttons
                break
            else:
                prev_layer_buttons += len(layer_row)

        button_item = b_row[b_index]
        if type(button_item) is dict:
            button_item['type'] = 'held'
        else:
            button_dict = {
                't': button_item,
                'type': 'held',
            }
            b_row[b_index] = button_dict

    return keymap


def check_undefined_behaviors(keymap):
    undefined_behaviors = []
    for layer in keymap['layers'].values():
        for row in layer:
            for key in row:
                if type(key) is str and key.startswith('&') and len(key) > 1:
                    undefined_behaviors.append(key)

    # Dedupe list
    undefined_behaviors = list(set(undefined_behaviors))

    if len(undefined_behaviors) > 0:
        print('=================== WARNING ===================')
        print('You have the following undefined behaviors:')
        for behavior in undefined_behaviors:
            print(f'    - {behavior}')
        print('===============================================')

    return len(undefined_behaviors)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'keymap_yaml_path',
        help='Path to the YAML keymap file.',
    )

    if len(sys.argv) == 1:
        parser.print_help()
        exit(1)

    args = parser.parse_args()

    keymap = get_keymap_yaml(args.keymap_yaml_path)
    keymap = adjust_combo(keymap, combo_locations)
    keymap = remove_layers(keymap, delete_layers)
    keymap = highlight_buttons(keymap, pressed_buttons)
    undefined_behaviors = check_undefined_behaviors(keymap)

    write_keymap_yaml(args.keymap_yaml_path, keymap)

    if(undefined_behaviors > 0):
        exit(1)


if __name__ == "__main__":
    main()
