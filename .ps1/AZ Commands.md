## 7. Help & Discovery
- `Get-Command -Module Az.*`: Lists every command available in the Az module.
- `Get-Help <CommandName> -Examples`: Shows real-world usage examples for any cmdlet.

## 8. Common Submodule Usage Guide
A breakdown of what the major submodules in your environment are used for.

### Core & Infrastructure
- **Az.Accounts**: The foundation for authentication, managing contexts, and subscription switching.
- **Az.Resources**: Lifecycle management for Resource Groups, Tags, and ARM/Bicep deployments.
- **Az.Compute**: Management of Virtual Machines (VMs), Managed Disks, and Snapshots.
- **Az.Network**: Core networking: VNETs, Subnets, Network Security Groups (NSGs), and Load Balancers.

### Storage & Data Services
- **Az.Storage**: Data management for Blobs, File Shares, Queues, and Tables.
- **Az.Sql**: Configuration and management of Azure SQL Databases and Managed Instances.
- **Az.CosmosDB**: Managing globally distributed NoSQL database accounts and containers.
- **Az.DataFactory**: Orchestrating data movement and integration (ETL) workflows.

### Web, Containers & Serverless
- **Az.Websites**: Managing App Services, Web Apps, and App Service Plans.
- **Az.Functions**: Deployment and scaling of serverless Azure Functions.
- **Az.Aks / Az.ContainerInstance**: Orchestration of Kubernetes clusters and standalone containers (ACI).
- **Az.LogicApp**: Automation of business workflows and system integrations.

### Security & Governance
- **Az.KeyVault**: Securely managing secrets, encryption keys, and SSL certificates.
- **Az.Security / Az.SecurityInsights**: Microsoft Defender for Cloud and Sentinel (SIEM) management.
- **Az.ManagedServiceIdentity**: Handling Managed Identities for passwordless service-to-service auth.

### Monitoring & Operations
- **Az.Monitor / Az.OperationalInsights**: Configuring metrics, logs, and Log Analytics workspaces.
- **Az.Automation**: Managing Automation Accounts, hybrid workers, and Runbooks.
- **Az.Billing / Az.CostManagement**: Tracking consumption, managing invoices, and setting budgets.
