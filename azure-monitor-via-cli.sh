az login

az account set --subscription "Contoso Sports"

az vm list --resource-group nfslinux-rg --output table

az vm list --resource-group nfslinux-rg --show-details

az vm show --resource-group nfslinux-rg --name nfslinuxvm01 --query 'id'

az vm extension show --resource-group kemlinux-rg --vm-name kemlinuxvm02 --name Microsoft.Insights.VMDiagnosticsSettings --query 'settings.xmlCfg' --output tsv | base64 --decode

https://docs.microsoft.com/en-us/azure/virtual-machines/linux/classic/diagnostic-extension

az login

az account set --subscription "Contoso Sports"

az vm list --resource-group nfslinux-rg --output table

az vm diagnostics get-default-config

az-vm diagnostics set --help

resourceId=$(az vm show --resource-group nfslinux-rg --name nfslinuxvm01 --query 'id' --output tsv)

az monitor metric-definitions list --resource-id $resourceId

az monitor metrics list --metric-names "Percentage CPU" --resource-id $resourceId --time-grain PT1M

https://msdn.microsoft.com/en-us/library/azure/dn931943.aspx

# Log Retention
# Activity Log - 90-days, but can be exported to Storage for unlimited retention
# Metrics - 30 days
# Diagnostic Logs - unlimited retention, or up to 365 days
# Log Analytics - 7-days in free tier, up to 730-days (2-years) in paid tiers

# Azure Monitor documentation - https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/monitoring-overview

# Log Analytics search syntax - https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-search-reference

# Monitoring RBAC roles - https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/monitoring-roles-permissions-security