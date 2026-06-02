# Solr Initializer for Dataverse
# Bakes the Dataverse Solr schema into a lightweight image that ensures
# collection1 exists with the correct config on every startup.
FROM gdcc/configbaker:latest AS schema-source
FROM solr:9.3.0

USER root

# Copy Dataverse Solr schema from configbaker
COPY --from=schema-source /template/conf /opt/dataverse-solr-conf

# Copy the init script
COPY init-solr.sh /docker-entrypoint-initdb.d/init-solr.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-solr.sh

USER solr

ENTRYPOINT ["/docker-entrypoint-initdb.d/init-solr.sh"]
