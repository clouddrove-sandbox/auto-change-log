## Vritual Network and Subnet Creation

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}


locals {
  resource_group_name = var.resource_group_name
  location            = var.location
 e               = "Standard_D2_v3"
    os_type               = "Linux"
    ena = false
    min_count             = null
    type                  = "VirtualMachineScaleSets"
    node_taints           = null
    vnet_su

  name        = var.name
  environment = var.environment
  managedby   = var.managedby
  label_order = var.label_order
  repository  = var.repository
}

res          
  }
  d       = local.default_node_pool.max_pods
    os_disk_type        = local.default_node_pool.os_disk_type
    os_disk_size_gb     = local.default_node_pool.os_disk_size_gb
    type                = local.default_node_pool.type
    vnet
fender_enabled ? ["microsoft_defender"] : []

 
 


resource "azurerm_kubernetes_cluster_node_pool" "node_pools" {

  count                 = length(local.nodes_pools)
  kubernetes_cluster_id = join("", azurerm_kubernetes_cluster.aks.*.id)
  name                  = local.nodes_pools[count.index].name
  vm_size               = local.nodes_pools[count.index].vm_size
  os_type               = local.nodes_pools[count.index].os_type
  os_disk_type          = local.nodes_pools[count.index].os_disk_type
  os_disk_size_gb       = local.nodes_pools[count.index].os_disk_size_gb
  vnet_subnet_id        = local.nodes_pools[count.index].vnet_subnet_id
  enable_auto_scaling   = local.nodes_pools[count.index].enable_auto_scaling
  node_count            = local.nodes_pools[count.index].count
  min_count             = local.nodes_pools[count.index].min_count
  max_count             = local.nodes_pools[count.index].max_count
  max_pods              = local.nodes_pools[count.index].max_pods
  enable_node_public_ip = local.nodes_pools[count.index].enable_node_public_ip
}

# Allow aks system indentiy access to encrpty disc
resource "azurerm_role_assignment" "aks_system_identity" {
  count                = var.enabled && var.azurerm_disk_encryption_set ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.aks[0].identity[0].principal_id
  scope                = join("", azurerm_disk_encryption_set.main.*.id)
  role_definition_name = "Contributor"
}

# Allow user assigned identity to manage AKS items in MC_xxx RG
resource "azurerm_role_assignment" "aks_user_assigned" {
  count                = var.enabled ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
  scope                = format("/subscriptions/%s/resourceGroups/%s", data.azurerm_subscription.current.subscription_id, join("", azurerm_kubernetes_cluster.aks.*.node_resource_group))
  role_definition_name = "Contributor"
}

resource "azurerm_user_assigned_identity" "aks_user_assigned_identity" {
  count = var.enabled && var.private_cluster_enabled && var.private_dns_zone_type == "Custom" ? 1 : 0

  name                = format("aks-%s-identity", module.labels.id)
  resource_group_name = local.resource_group_name
  location            = local.location
}


resource "azurerm_role_assignment" "aks_uai_private_dns_zone_contributor" {
  count = var.enabled && var.private_cluster_enabled && var.private_dns_zone_type == "Custom" ? 1 : 0

  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = join("", azurerm_user_assigned_identity.aks_user_assigned_identity.*.principal_id)
}

resource "azurerm_role_assignment" "aks_uai_vnet_network_contributor" {
  count                = var.enabled && var.private_cluster_enabled && var.private_dns_zone_type == "Custom" ? 1 : 0
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = join("", azurerm_user_assigned_identity.aks_user_assigned_identity.*.principal_id)
}

resource "azurerm_key_vault_key" "example" {
  count        =  var.enabled && var.azurerm_disk_encryption_set ? 1 : 0
  name         = format("aks-%s-vault-key", module.labels.id)
  key_vault_id = var.key_vault_id
  key_type     = "RSA"
  key_size     = 2048
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

resource "azurerm_disk_encryption_set" "main" {
  count               = var.enabled && var.azurerm_disk_encryption_set ? 1 : 0
  name                = format("aks-%s-dsk-encrpt", module.labels.id)
  resource_group_name = local.resource_group_name
  location            = local.location
  key_vault_key_id    = var.azurerm_disk_encryption_set ? join("", azurerm_key_vault_key.example.*.id) : null

  identity {
    type = "SystemAssigned"
  }
}

