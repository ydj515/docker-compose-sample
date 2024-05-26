# docker-compose-elk

docker-compose up setup



GET /_cat/nodes?v

GET /_cluster/health?pretty

GET /_cat/indices?v

PUT /_cluster/settings
{
  "persistent": {
    "index.auto_create_index": "true"
  }
}
