variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet1_cidr" {
  description = "CIDR block for subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet2_cidr" {
  description = "CIDR block for subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet3_cidr" {
  description = "CIDR block for subnet 3"
  type        = string
  default     = "10.0.3.0/24"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "kms_key_alias_name" {
  description = "Alias name for the KMS key used for EKS cluster encryption"
  type        = string
  default     = "alias/eks-key"
}

variable "node_groups" {
  description = "List of node groups to create in the EKS cluster"
  type = list(object({
    name          = string
    instance_type = string
    desired_size  = number
    min_size      = number
    max_size      = number
    disk_size     = optional(number, 200)
    ami_type      = optional(string, "AL2_ARM_64")
    capacity_type = optional(string, "ON_DEMAND")
    labels        = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = [
    {
      name          = "my-eks-node-group"
      instance_type = "m6g.large"
      desired_size  = 1
      min_size      = 1
      max_size      = 1
      labels = {
        "nodetype" = "apm"
      }
      taints = [
        {
          key    = "nodetype"
          value  = "apm"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  ]

  validation {
    condition = alltrue([
      for ng in var.node_groups : (
        ng.min_size <= ng.desired_size &&
        ng.desired_size <= ng.max_size
      )
    ])
    error_message = "For each node group, ensure min_size <= desired_size <= max_size"
  }
}

variable "enabled_cluster_log_types" {
  description = "List of EKS cluster control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "endpoint_private_access" {
  description = "Whether the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "service_ipv4_cidr" {
  description = "The CIDR block to assign Kubernetes service IP addresses from"
  type        = string
  default     = "10.100.0.0/16"
}

variable "eks_cluster_sg_name" {
  description = "Name of the EKS cluster security group"
  type        = string
  default     = "eks-cluster-sg"
}

variable "eks_node_sg_name" {
  description = "Name of the EKS node security group"
  type        = string
  default     = "eks-node-sg"
}
