variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"  # Free tier eligible region
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "secure-supply-chain"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "github_repository" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "your-username/secure-supply-chain-cicd"  # Update this
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "secure-supply-chain"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
