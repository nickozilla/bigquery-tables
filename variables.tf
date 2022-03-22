variable "table_default" {
  description = "A table with optional accesses"
  type = object({
    dataset_name = string
    kms_key_name = string
    tables = list(object({
      table_name = string
      accesses = optional(list(object({
        role = string
        members = list(string)
      })))
    }))
  })
  default = {
    dataset_name = null
    kms_key_name = null
    tables = []
  }
}
