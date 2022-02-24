FROM containers.intersystems.com/intersystems/iris-community:2022.1.0.114.0

EXPOSE 8000

COPY ./requirements.txt /home/irisowner/django-todo/

ENV PATH=/home/irisowner/.local/bin:${PATH}

RUN \
  pip3 install /usr/irissys/dev/python/*.whl && \
  cd /home/irisowner/django-todo && \
  pip3 install -r requirements.txt

COPY ./ /home/irisowner/django-todo/

ENTRYPOINT [ "/tini", "--", "/home/irisowner/django-todo/entrypoint.sh" ]
