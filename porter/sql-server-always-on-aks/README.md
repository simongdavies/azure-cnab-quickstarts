# SQL Server Always On for AKS

This Bundle installs a SQL Server always on availability group on a new AKS Cluster, on install it will:

* Create a new AKS Cluster
* Deploy the SQL Server Operator
* Create Secrets for SQL Server sa password and master password
* Deploy SQL Server Containers, persistent volumes, persistent volume claims and load balancers
* Create services to connect to primary and secondary replicas

It creates an AKS Cluster with 4 nodes with agent VM Size of Standard_DS2_v2, the Cluster is created without enabling RBAC.

Full details can be found [here](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-kubernetes-deploy?view=sqlallproducts-allversions)

## Deploy from Azure


You will need to create a service principal in order to use the 'Deploy from Azure' buttons.


For detailed instructions on deploying from Azure, including how to setup the service principal, see [Consuming: Deploy from Azure](../../docs/consuming.md#deploy-from-azure)

### Simple deployment


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-cnab-quickstarts%2Fmaster%2Fporter%2Fsql-server-always-on-aks%2Fazuredeploy-simple.json" target="_blank"><img src="https://raw.githubusercontent.com/endjin/CNAB.Quickstarts/master/images/Deploy-from-Azure.png"/></a>

### Advanced deployment


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-cnab-quickstarts%2Fmaster%2Fporter%2Fsql-server-always-on-aks%2Fazuredeploy-advanced.json" target="_blank"><img src="https://raw.githubusercontent.com/endjin/CNAB.Quickstarts/master/images/Deploy-from-Azure.png"/></a>


## Deploy from Cloud Shell


For detailed instructions on deploying from Cloud Shell, including how to setup the Cloud Shell environment, see [Consuming: Deploy from Cloud Shell](../../docs/consuming.md#deploy-from-cloud-shell)


```porter install --tag cnabquickstarts.azurecr.io/porter/sql-server-always-on-aks/bundle:latest -d azure```


## Parameters and Credentials

 | Name | Description | Default | Required | 
 | --- | --- | --- | --- | 
 | aks_cluster_name | The name to use for the AKS Cluster |  | No
aks_resource_group | The name of the resource group to create the AKS Cluster in |  | No
azure_client_id | AAD Client ID for Azure account authentication - used for AKS Cluster SPN details and for authentication to azure to get KubeConfig |  | Yes
azure_client_secret | AAD Client Secret for Azure account authentication - used for AKS Cluster SPN details and for authentication to azure to get KubeConfig |  | Yes
azure_location | The Azure location to create the resources in |  | Yes
azure_subscription_id | Azure Subscription Id used to set the subscription where the account has access to multiple subscriptions |  | Yes
azure_tenant_id | Azure AAD Tenant Id for Azure account authentication - used to authenticate to Azure to get KubeConfig |  | Yes
porter-debug | Print debug information from Porter when executing the bundle |  | No
sql_masterkeypassword | The Password for the SQL Server Master Key |  | Yes
sql_sapassword | The Password for the sa user in SQL Server |  | Yes | 


## Known issues

- [SQL Server pods error on startup](https://github.com/Azure/azure-cnab-quickstarts/issues/71)
- [Test bundle](https://github.com/Azure/azure-cnab-quickstarts/issues/82)