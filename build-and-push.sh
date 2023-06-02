#!/bin/bash

TAG=$(head -n 1 ./VERSION | cut -d'.' -f 1-3)

docker buildx build -t amirsamary/django-iris-todo:$TAG ./app

docker push amirsamary/django-iris-todo:$TAG