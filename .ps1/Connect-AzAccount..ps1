Connect-AzAccount
\$Credential = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $Credential -TenantId $TenantId
Connect-AzAccount -Environment AzureUSGovernment -Credential $Credential -TenantId $TenantId
Get-AzContext -ListAvailable
Get-AzSubscription
Get-Command -Module Az.Account
Get-Command -Module Az.Compute -Name '*VM*'