# Author: Katharine Murphy
# --------------------------------------------------------------------------------------------------------------
### INSTRUCTIONS FOR USE ###
# --------------------------------------------------------------------------------------------------------------
# Currently, this is an experimental and fairly manual operation.
# Run the doc autogen command on the source code: https://github.com/ConsenSys/UniversalToken/contracts folder:
# `npx solidity-docgen --solc-module solc-0.8`.
# Paste the generated markdown into the `docs/api` folder.
# Run the script from the root `docs`.
# Paste the resulting output directly into the `mkdocs.yaml` file at the end of the nav section.
# --------------------------------------------------------------------------------------------------------------
# This script is a work in progress which can eventually run on every docs update in the main repo.

import os

def list_files(startpath):
    for root, dirs, files in sorted(os.walk(startpath)):
            level = root.replace(startpath, '').count(os.sep)
            indent = ' ' * 4 * (level)
            print('  {}- {}:'.format(indent, os.path.basename(root).capitalize()),)
            subindent = ' ' * 4 * (level + 1)
            for f in sorted(files):
                title = str(f).replace('.md', '')
                filepath = os.path.join(root, f)
                print('  {}- {}:  {}'.format(subindent, title, filepath))

list_files("API")