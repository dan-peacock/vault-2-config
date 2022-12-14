provider "vault" {
  address = var.vault_url
  token = var.vault_token
}

# Configure Login
resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

# Generate password 
provider "random" {}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create a user
resource "vault_generic_endpoint" "user" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/${var.username}"
  ignore_absent_fields = true
  data_json = <<EOT
{
  "policies": ["hcp-root"],
  "password": "${random_password.password.result}"
}
EOT
}

module "vault_aws_secret_backend" {
  source = "./modules/aws"
  count = var.aws_enabled ? 1 : 0

  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}

module "vault_azure_secret_backend" {
  source = "./modules/azure"
  count = var.azure_enabled ? 1 : 0

  subscription_ID = var.subscription_ID
  tenant_ID = var.tenant_ID
  SP_Password = var.SP_Password
  SP_AppID = var.SP_AppID
}


# Add Vault Info to Terraform Variable Set
provider "tfe" {
  token = var.tfc_token
}

resource "tfe_variable_set" "vault_user_details" {
  name         = "Vault User Details"
  description  = "Variable set applied to all workspaces."
  global       = true
  organization = var.tfc_org_name
}

resource "tfe_variable" "vault_password" {
  key             = "vault_password"
  value           = nonsensitive(random_password.password.result)
  sensitive       = false
  category        = "terraform"
  description     = "Vault password"
  variable_set_id = tfe_variable_set.vault_user_details.id
}

resource "tfe_variable" "vault_username" {

  key             = "vault_username"
  value           = var.username
  sensitive       = true
  category        = "terraform"
  description     = "Vault username"
  variable_set_id = tfe_variable_set.vault_user_details.id
}
