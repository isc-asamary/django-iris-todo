#!/bin/bash

set -m

cd /usr/src/app

python3 manage.py migrate
gunicorn --bind 0.0.0.0:8000 todoApp.wsgi --workers=5 --threads=1