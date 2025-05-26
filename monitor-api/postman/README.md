# Using the Postman Collection & Environment

## Background

The provided Postman collection and environment are exports from the [public Citrix Postman workspace](https://www.postman.com/citrix-data-access/workspace/citrix-data-public-workspace). They include several examples of how OData queries can be used to extract useful datasets.

## How to import

The JSON files can be imported either at an installed Postman application, or on a Postman workspace, following the [documented guidelines](https://learning.postman.com/docs/getting-started/importing-and-exporting/importing-and-exporting-overview/).

## The Monitor OData environment

| Variable | Applicable setup | Value hint |
| -------- | ------- | ---- |
| env | Both |  Acceptable values: cloud or onprem |
| client_id | Cloud | Details [here](https://developer-docs.citrix.com/en-us/citrix-cloud/citrix-cloud-api-overview/get-started-with-citrix-cloud-apis). UUID |
| client_secret | Cloud | Details [here](https://developer-docs.citrix.com/en-us/citrix-cloud/citrix-cloud-api-overview/get-started-with-citrix-cloud-apis) ||
| customer_id | Cloud | Citrix Cloud customer ID ||
| gateway_url | Cloud | https://api.cloud.com/cctrustoauth2 |
| baseurl_cloud | Cloud | https://api.cloud.com/monitorodata |
| token | Cloud | This is automatically populated|
| baseurl_onprem | On-Premises | The Monitor service host. Usually same as DDC. Example: http://172.191.116.40|
| username | On-Premises ||
| password | On-Premises ||

## The Monitor OData collection

The provided collection consists of the following:

-  *POST - Cloud Authentication*: This is the request that generates a valid bearer token. The generated token is automatically stored in the `token` environment variable, used for authenticating the OData requests.
-  *GET - Metadata*: A simple request for getting the OData API metadata.
-  OData examples, grouped by entity: Multiple examples for extracting insights through the Machine, Session, Connection, Application etc entities.

**Note** that the OData query authentication [headers](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/overview#required-headers) are automatically generated as part of the collection pre-request script.
