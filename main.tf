terraform {
  experiments = [module_variable_optional_attrs]
}

locals {
  config_file = try(file("./projects/zeta/${terraform.workspace}.yaml"),file("./env/beta/${terraform.workspace}.yaml"),file("./projects/alpha/${terraform.workspace}.yaml"))
  config = yamldecode(local.config_file)
  stage = local.config.stage
  project = terraform.workspace
  subdirectory = local.config.subdirectory

  all_datasets = tolist([for i in local.config.datasets : merge(var.table_default, i)])

  merged_map =  { for dataset in local.all_datasets: dataset.dataset_name => dataset }
  dataset_table = merge([ for dataset in local.merged_map: { for table in dataset.tables: "${dataset.dataset_name}-${table.table_name}" => merge({dataset = dataset, table = table})} ]...)
  dataset_table_role = merge([ for ds_table in local.dataset_table: { for table_role in ds_table.table.accesses: "${ds_table.dataset.dataset_name}-${ds_table.table.table_name}-${table_role.role}" => merge({ds_table = ds_table, table_role = table_role}) } ]...)
}

resource "google_bigquery_table" "default" {
  for_each   = local.dataset_table
  dataset_id = each.value.dataset.dataset_name
  table_id   = each.value.table.table_name
  project    = local.project
  deletion_protection = try(each.value.table.deletion_protection, true)
  encryption_configuration { 
    kms_key_name = each.value.dataset.kms_key_name
  }
  schema     = jsonencode(jsondecode(file("./schemas/${local.stage}/${local.subdirectory}/${local.project}/${each.value.dataset.dataset_name}.json"))["tables"][each.value.table.table_name])
}

resource "google_bigquery_table_iam_binding" "binding" {
  for_each = local.dataset_table_role
  project = local.project
  dataset_id = each.value.ds_table.dataset.dataset_name
  table_id = each.value.ds_table.table.table_name
  role = each.value.table_role.role
  members = each.value.table_role.members
  depends_on = [google_bigquery_table.default]
}
