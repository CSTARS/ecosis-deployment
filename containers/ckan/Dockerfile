FROM ubuntu:18.04

ARG CKAN_VERSION
ENV CKAN_VERSION ${CKAN_VERSION}
ENV GIT_URL "git+https://github.com/ckan/ckan.git@ckan-$CKAN_VERSION#egg=ckan[requirements]"


# more help on this https://hub.docker.com/r/teraproc/postfix/~/dockerfile/
# RUN echo "postfix postfix/main_mailer_type string Internet site" > /preseed.txt
# RUN echo "postfix postfix/mailname string ecosis.org" >> /preseed.txt

RUN export DEBIAN_FRONTEND=noninteractive
# RUN debconf-set-selections /preseed.txt

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3-dev libpq-dev wget lsb-release \
    python3-virtualenv python3-wheel \
    python3-pip python3-venv git-core vim \
    build-essential unzip zip awscli mongodb-clients \
    --fix-missing
# RUN rm /preseed.txt

# need the Postgresql 13 libraries
RUN echo 1 && echo $(lsb_release -cs)
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list
RUN apt-get update && apt-get install -y postgresql-client-13

# install matching (3.4) mongodb tool set
# RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
# RUN echo "deb http://repo.mongodb.org/apt/debian focal/mongodb-org/3.4 main" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
# RUN apt-get update && apt-get install -y mongodb-org-tools mongodb-org-shell

# RUN easy_install pip
RUN pip3 install setuptools==44.1.0
RUN pip3 install --upgrade pip
RUN pip3 install debugpy

# create dir
RUN mkdir -p /ckan

RUN cd /ckan && \
    pip3 install --ignore-installed -e $GIT_URL

ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# RUN pip3 install testrepository
# RUN pip3 install --upgrade --no-cache-dir -r /ckan/src/ckan/requirement-setuptools.txt
# RUN pip3 install --upgrade -r /ckan/src/ckan/requirements.txt
# RUN pip3 install polib

# RUN cd /ckan/src/ckan && \
#     paster make-config ckan /etc/ckan/default.ini

RUN mkdir /etc/ckan
RUN ckan generate config /etc/ckan/default.ini

RUN if [ -f /etc/ckan/who.ini ]; then \
    rm /etc/ckan/who.ini; \
fi

RUN ln -s /ckan/src/ckan/ckan/config/who.ini /etc/ckan/who.ini

COPY ./run.sh /etc/ckan/run.sh
COPY ./init-pg.sh /etc/ckan/init-pg.sh
COPY ./setup-ini.sh /etc/ckan/setup-ini.sh
COPY ./setup-simple-ini.sh /etc/ckan/setup-simple-ini.sh
COPY ./template.ini /etc/ckan/template.ini
COPY ./create_backup.sh /etc/ckan/create_backup.sh
COPY ./backup_cron.sh /etc/ckan/backup_cron.sh
COPY ./restore_backup.sh /etc/ckan/restore_backup.sh
COPY ./wait-for-it.sh /etc/ckan/wait-for-it.sh
COPY ./debug_server.py /etc/ckan/debug_server.py
COPY ./debug.sh /etc/ckan/debug.sh

# RUN apt-get clean

EXPOSE 5000

CMD bash -c '/etc/ckan/run.sh'
