FROM solr:5.3

USER root

COPY ./solrconfig.zip /solrconfig.zip
RUN unzip /solrconfig.zip -d /opt/solr/server/solr/ckan
# don't have permission.
RUN rm /solrconfig.zip