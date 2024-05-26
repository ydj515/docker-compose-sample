ARG ELASTICSEARCH_VERSION
ARG ELASTICSEARCH_IMAGE

# https://www.docker.elastic.co/
FROM ${ELASTICSEARCH_IMAGE}:${ELASTICSEARCH_VERSION}

# Add your elasticsearch plugins setup here
# Example: RUN elasticsearch-plugin install analysis-icu
RUN elasticsearch-plugin install analysis-nori