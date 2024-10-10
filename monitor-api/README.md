# Introduction 

Citrix Director is the go to tool for troubleshooting and monitoring the CVAD environment. It helps in monitoring and triaging live sessions through Activity Manager, User Details, Client Details and Machine details pages. Director also provides reporting functionality through trends pages which covers the historical reports on the number of sessions, concurrent sessions, failures, logon duration trends, probes etc.

While Citrix Director provides basic functionalities, there can be specific usecases on generating customized reports and using the data related to sessions, failures etc for the bigger usecase or to make the data available as part of other dashboards. These usecases can be addressed through Odata APIs for both Oprem and Cloud CVAD.

# Benefits

The examples shared use the Citrix Monitor Service REST APIs to collect, analyze, and categorize data from the Citrix Virtual Apps and Desktops and Citrix DaaS. It also provides a walkthrough of the CVAD dataset that is available through Odata API and a hands-on experience on how to play around with the data from CVAD environment through Powershell, Postman and Curl. 

The examples shared enable accessing Citrix Monitor Service API using an OData consumer. With this data, customer admins can create a single pane of glass for the Citrix stack and build their own monitoring and troubleshooting dashboards for both admins and helpdesk. Admins can also build Integration with 3rd-party systems or data lake for observability or reporting on VDI usage.

# Environment setup

Odata URI : http://{DeliveryController}/Citrix/Monitor/OData/v4/Data/

Authentication on Cloud : Odata API on cloud uses bearer token for authentication. Steps to generate bearer token can be found [here](https://developer.cloud.com/citrix-cloud/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis).


Authentication onPrem : Odata Oprem uses NTLM authentication mechanism. Username and password with right set of permissions on CVAD environment will help in executing the API.

# Powershell examples
[Here](./powershell/Demo_OnPrem.ps1)

# Postman examples
There are 2 ways to access the Postman examples for Monitor API.

## 1. Via Postman public workspace
[Here](https://www.postman.com/citrix-data-access/workspace/citrix-data-public-workspace)

## 2. Importing collection and environments
| S.No | Description | Collection | Environment | Comments |
| ---- | ---- | ---- | ---- | ---- |
| 1. | On-Prem Demo | [link](./postman/Demo_OnPrem.postman_collection.json) | [link](./postman/Demo_OnPrem.postman_environment.json) | |
| 2. | Cloud Demo | [link](./postman/Demo_DaaS.postman_collection.json) | [link](./postman/Demo_DaaS.postman_environment.json) | |

# Curl examples
[Here](./curl/Demo_OnPrem.txt)

# Useful links

1. [OData syntax](http://docs.oasis-open.org/odata/odata-data-aggregation-ext/v4.0/cs01/odata-data-aggregation-ext-v4.0-cs01.html)

2. [Monitor Data Model](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/apis)

3. [Monitor API details(Onprem)](https://developer-docs.citrix.com/en-us/monitor-service-odata-api/on-prem-odata)

4. [Accessing Monitor API in Cloud](https://developer.cloud.com/citrixworkspace/citrix-daas/accessing-monitor-service-data-in-citrix-cloud/docs/overview)

5. [Authentication in Cloud](https://developer.cloud.com/citrix-cloud/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis)
