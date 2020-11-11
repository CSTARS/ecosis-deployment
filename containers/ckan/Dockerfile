FROM ubuntu:xenial

ARG CKAN_VERSION
ENV CKAN_VERSION ${CKAN_VERSION}
ENV GIT_URL "git+https://github.com/ckan/ckan.git@ckan-$CKAN_VERSION#egg=ckan"


# more help on this https://hub.docker.com/r/teraproc/postfix/~/dockerfile/
RUN echo "postfix postfix/main_mailer_type string Internet site" > /preseed.txt
RUN echo "postfix postfix/mailname string ecosis.org" >> /preseed.txt

RUN DEBIAN_FRONTEND=noninteractive
RUN debconf-set-selections /preseed.txt
RUN apt-get update

# you can select Internet Site and localhost for postfix/smtp server
RUN apt-get install -y python-dev python-setuptools build-essential zip \
    libpq-dev git-core postfix postgresql-client unzip awscli --fix-missing
RUN rm /preseed.txt

# install matching (3.4) mongodb tool set
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
RUN echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/3.4 main" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
RUN apt-get update
RUN apt-get install -y mongodb-org-tools mongodb-org-shell

RUN easy_install pip

# create dir
RUN mkdir -p /ckan

RUN cd /ckan && \
    pip install -e $GIT_URL

RUN pip install testrepository
RUN pip install --upgrade -r /ckan/src/ckan/requirements.txt
RUN pip install polib

RUN cd /ckan/src/ckan && \
    paster make-config ckan /etc/ckan/default.ini

RUN if [ -f /etc/ckan/who.ini ]; then \
        rm /etc/ckan/who.ini; \
    fi

RUN ln -s /ckan/src/ckan/who.ini /etc/ckan/who.ini

COPY ./run.sh /etc/ckan/run.sh
COPY ./init-pg.sh /etc/ckan/init-pg.sh
COPY ./setup-ini.sh /etc/ckan/setup-ini.sh
COPY ./setup-simple-ini.sh /etc/ckan/setup-simple-ini.sh
COPY ./template.ini /etc/ckan/template.ini
COPY ./create_backup.sh /etc/ckan/create_backup.sh
COPY ./backup_cron.sh /etc/ckan/backup_cron.sh
COPY ./restore_backup.sh /etc/ckan/restore_backup.sh
COPY ./wait-for-it.sh /etc/ckan/wait-for-it.sh

RUN apt-get clean

EXPOSE 5000

CMD bash -c '/etc/ckan/run.sh'
