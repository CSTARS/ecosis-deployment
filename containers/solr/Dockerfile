ARG SOLR_VERSION
FROM solr:${SOLR_VERSION}

USER root

# solr must run as solr user, but we need solr
# user to be able to change write permission of data mount
RUN apt-get update && apt-get -y install sudo
RUN adduser solr sudo
RUN echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN passwd --delete solr

COPY ./solrconfig.zip /solrconfig.zip
RUN unzip /solrconfig.zip -d /opt/solr/server/solr/ckan
RUN chown -R solr:solr /opt/solr/server/solr/ckan
# don't have permission.
RUN rm /solrconfig.zip

USER solr