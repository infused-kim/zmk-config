#!/usr/bin/env python3

import copy
import argparse
import sys
import oyaml as yaml

# Settings
pressed_buttons = [
    ('123', 34),
    ('hjkl', 31),
    ('ext', 31),
    ('ext', 34),
]

delete_layers = []

combo_locations = {
}


def get_keymap_yaml(file_path):
    with open(file_path, 'r') as f:
        keymap = yaml.safe_load(f)

    return keymap


def write_keymap_yaml(file_path, keymap):
    with open(file_path + "updated", 'w') as f:
        yaml.dump(keymap, f)


def adjust_combo(keymap, combo_locations):
    keymap = copy.deepcopy(keymap)

    for combo in keymap['combos']:
        if len(combo['p']) > 2:
            combo['a'] = 'top'

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
        b_num = button[1]

        layer = keymap['layers'].get(b_layer, None)
        if layer is None:
            print(f"Can't highlight button: {button}: Layer not found")
            continue

        # print(f"INDEX: {b_num}")
        # print(f"LAYER: {layer}")
        # print(f"MATH: [{int(b_num/10)}][{b_num % 10}]")
        button_item = layer[int(b_num/10)][b_num % 10]

        print(f"ITEM: {button_item}")
        if type(button_item) is dict:
            button_item['type'] = 'held'
        else:
            button_dict = {
                't': button_item,
                'type': 'held',
            }
            layer[int(b_num/10)][b_num % 10] = button_dict

    print(f"HIGHLIGHTED: {keymap}")
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
    if (undefined_behaviors > 0):
        exit(1)


if __name__ == "__main__":
    main()
