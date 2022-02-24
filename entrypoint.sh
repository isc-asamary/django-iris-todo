#!/bin/bash

set -m

/iris-main "$@" &

/usr/irissys/dev/Cloud/ICM/waitISC.sh
iris session iris -U%SYS '##class(Security.Users).Create("django","%ALL","django")' || true

cd /home/irisowner/django-todo
python3 manage.py migrate
gunicorn --bind 0.0.0.0:8000 todoApp.wsgi --workers=5 --threads=1 --daemon 

fg %1