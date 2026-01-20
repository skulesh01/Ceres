# ============================================================================
# CERES AWS Infrastructure Module
# ============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# ============================================================================
# VPC Infrastructure
# ============================================================================

module "aws_vpc" {
  count   = var.aws_enabled ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs              = var.aws_availability_zones
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ============================================================================
# Security Groups
# ============================================================================

resource "aws_security_group" "eks_cluster" {
  count = var.aws_enabled ? 1 : 0

  name_prefix = "${var.project_name}-eks-"
  vpc_id      = module.aws_vpc[0].vpc_id
  description = "Security group for CERES EKS cluster"

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================================
# EKS Cluster
# ============================================================================

module "aws_eks" {
  count   = var.aws_enabled ? 1 : 0
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.aws_vpc[0].vpc_id
  subnet_ids = concat(module.aws_vpc[0].private_subnets, module.aws_vpc[0].public_subnets)

  enable_irsa = true

  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = [var.aws_instance_type]
  }

  eks_managed_node_groups = {
    main = {
      name         = "${var.project_name}-node-group"
      min_size     = var.aws_node_count
      max_size     = var.aws_node_count * 2
      desired_size = var.aws_node_count

      instance_types = [var.aws_instance_type]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = var.environment
        Cluster     = var.project_name
      }

      taints = []

      tags = {
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
        "k8s.io/cluster-autoscaler/enabled"              = "true"
      }
    }
  }

  manage_aws_auth_configmap = true

  tags = {
    Cluster = var.cluster_name
  }
}

# ============================================================================
# RDS PostgreSQL Database
# ============================================================================

resource "aws_db_subnet_group" "postgres" {
  count       = var.aws_enabled ? 1 : 0
  name        = "${var.project_name}-postgres-subnet"
  subnet_ids  = module.aws_vpc[0].database_subnets
  description = "Subnet group for CERES PostgreSQL"

  tags = {
    Name = "${var.project_name}-postgres-subnet"
  }
}

resource "aws_security_group" "postgres" {
  count       = var.aws_enabled ? 1 : 0
  name_prefix = "${var.project_name}-postgres-"
  vpc_id      = module.aws_vpc[0].vpc_id
  description = "Security group for CERES PostgreSQL"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.aws_eks[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-postgres-sg"
  }
}

resource "aws_db_instance" "postgres" {
  count = var.aws_enabled ? 1 : 0

  identifier = "${var.project_name}-postgres"

  engine               = "postgres"
  engine_version       = var.postgres_version
  family               = "postgres${split(".", var.postgres_version)[0]}"
  major_engine_version = split(".", var.postgres_version)[0]

  instance_class          = var.postgres_instance_size
  allocated_storage       = var.postgres_storage_size
  storage_type            = "gp3"
  iops                    = 3000
  storage_throughput      = 125
  storage_encrypted       = true
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.project_name}-postgres-final-snapshot"

  db_subnet_group_name   = aws_db_subnet_group.postgres[0].name
  vpc_security_group_ids = [aws_security_group.postgres[0].id]
  publicly_accessible    = false

  db_name  = "ceres"
  username = "ceres"
  password = random_password.postgres[0].result
  port     = 5432

  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  enable_cloudwatch_logs_exports = ["postgresql"]
  enabled_cloudwatch_logs_exports = ["postgresql"]

  copy_tags_to_snapshot = true
  multi_az              = true

  tags = {
    Name = "${var.project_name}-postgres"
  }
}

resource "random_password" "postgres" {
  count            = var.aws_enabled ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ============================================================================
# ElastiCache Redis
# ============================================================================

resource "aws_elasticache_subnet_group" "redis" {
  count           = var.aws_enabled ? 1 : 0
  name            = "${var.project_name}-redis-subnet"
  subnet_ids      = module.aws_vpc[0].private_subnets
  description     = "Subnet group for CERES Redis"
}

resource "aws_security_group" "redis" {
  count       = var.aws_enabled ? 1 : 0
  name_prefix = "${var.project_name}-redis-"
  vpc_id      = module.aws_vpc[0].vpc_id
  description = "Security group for CERES Redis"

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.aws_eks[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-redis-sg"
  }
}

resource "aws_elasticache_cluster" "redis" {
  count                = var.aws_enabled ? 1 : 0
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.medium"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  
  subnet_group_name          = aws_elasticache_subnet_group.redis[0].name
  security_group_ids         = [aws_security_group.redis[0].id]
  automatic_failover_enabled = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis[0].result

  tags = {
    Name = "${var.project_name}-redis"
  }
}

resource "random_password" "redis" {
  count            = var.aws_enabled ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ============================================================================
# S3 для хранения артефактов и бэкапов
# ============================================================================

resource "aws_s3_bucket" "artifacts" {
  count  = var.aws_enabled ? 1 : 0
  bucket = "${var.project_name}-artifacts-${data.aws_caller_identity.current[0].account_id}"

  tags = {
    Name = "${var.project_name}-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count  = var.aws_enabled ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count  = var.aws_enabled ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================================
# Data sources
# ============================================================================

data "aws_caller_identity" "current" {
  count = var.aws_enabled ? 1 : 0
}
