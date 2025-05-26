# Citrix Monitor Service OData API

## Introduction

Citrix Director is the go to tool for troubleshooting and monitoring the CVAD environment. It helps in monitoring and triaging live sessions through Activity Manager, User Details, Client Details and Machine details pages. Director also provides reporting functionality through trends pages which covers the historical reports on the number of sessions, concurrent sessions, failures, logon duration trends, probes etc.

While Citrix Director provides basic functionalities, there can be specific use cases on generating customized reports and using the data related to sessions, failures etc for the bigger use case or to make the data available as part of other dashboards. These use cases can be addressed through OData APIs for both On-Prem and Cloud CVAD.

More details about the Monitor Service OData API can be found at the [developer documentation](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/overview).

## Benefits

The examples shared use the Citrix Monitor Service REST APIs to collect, analyze, and categorize data from the Citrix Virtual Apps and Desktops and Citrix DaaS. A walkthrough of the CVAD dataset that is available through the OData API is also provided, as well as a hands-on experience on how to play around with the data from a CVAD environment through Powershell, Postman and Curl.

The examples shared enable accessing Citrix Monitor Service API using an OData consumer. With this data, customer admins can create a single pane of glass for the Citrix stack and build their own monitoring and troubleshooting dashboards for both admins and helpdesk. Admins can also integrate with 3rd-party systems or data lakes for observability or reporting on VDI usage.

## Environment setup

**On-premises**

OData URI: `http[s]://{DeliveryController}/Citrix/Monitor/OData/v4/Data/`

Authentication: NTLM authentication is used for on-premises. Username and password with right set of permissions on CVAD environment will help in executing the API.

**Cloud**

OData URI: `https://api.cloud.com/monitorodata`

Authentication: OData API on cloud uses bearer token for authentication. Details can be found [here](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/overview#authentication). Steps to generate bearer token can be found [here](https://developer-docs.citrix.com/en-us/citrix-cloud/accessing-monitor-service-data-citrix-cloud-external/accessing-monitor-service-data-citrix-cloud-external).

## Powershell examples

OData API requests can be issued using Powershell. This is particularly useful for periodically running queries and collecting Monitor data.
Basic examples can be found at the [developer documentation](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/access-methods#access-using-powershell).
For more advanced script examples for making OData requests and collecting data, check the [Powershell section](./powershell).

## Postman examples

Postman is a popular API tool that provides an easy and flexible way of exploring a RESTful API like Monitor OData. A large number of OData query examples is provided, in the form of a Postman collection, accompanied by a Postman environment. There are 2 ways to access the Postman examples for Monitor API:

### 1. Postman public workspace

A ready to use collection is available at the [public Citrix workspace](https://www.postman.com/citrix-data-access/workspace/citrix-data-public-workspace), along with a Postman environment. Users can fork the collection and the environment under their own workspaces and try them out.

### 2. Importing collection and environment

The above Postman collection and environment have been exported in JSON format and are available to download and import at the [Postman section](./postman).

## Curl examples

[Here](./curl/Demo_OnPrem.txt)

## Useful links

1.  [OData syntax](http://docs.oasis-open.org/odata/odata-data-aggregation-ext/v4.0/cs01/odata-data-aggregation-ext-v4.0-cs01.html)

1.  [Getting started with Citrix Cloud APIs](https://developer.cloud.com/citrix-cloud/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis)
  
1.  [Authenticating Monitor Service OData API](https://developer-docs.citrix.com/en-us/citrix-cloud/accessing-monitor-service-data-citrix-cloud-external/accessing-monitor-service-data-citrix-cloud-external)

1.  [Accessing Monitor API in Cloud](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/access-methods)

1.  [Monitor Data Model](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/apis)