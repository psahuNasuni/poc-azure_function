variable "project" {
  type        = string
  description = "Project name"
  default     = "azuretf"
}

variable "output_path" {
  type        = string
  description = "function_path of filw where zip file is stored"
  default     = "./BlobExampleFunction.zip"
}
