# Create a SQL Server 2016 AlwaysOn Availability Group with Managed Disks on an existing VNET
This template will create a SQL Server 2016 AlwaysOn Availability Group cluster using Windows Server 2016 in an existing VNET and Active Directory environment.

This template creates the following resources by default:

+	A Premium Storage Account for storing VM disks for each storage node
+   A Standard Storage Account for a Cloud Witness
+	A Windows Server 2016 cluster for SQL Server 2016 AOAG nodes
+	One Availability Set for the cluster nodes

To deploy the required Azure VNET and Active Directory infrastructure, if not already in place, you may use <a href="https://github.com/Azure/azure-quickstart-templates/tree/master/active-directory-new-domain-ha-2-dc">this template</a> to deploy the prerequisite infrastructure. 

Click the button below to deploy from the portal:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchagarw%2FMDPP%2Fmaster%2F301-sql-alwayson-md%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fchagarw%2FMDPP%2Fmaster%2F301-sql-alwayson-md%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

Built by: [robotechredmond](https://github.com/robotechredmond)

