# Local run without Docker
# Prerequisite python and pip
# EXAMPLE USAGE: ./run.sh

virtualenv venv
source venv/bin/activate
pip3 install -r requirements.txt
mkdocs serve --strict

