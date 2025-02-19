resource "aws_security_group" "eks_cluster_sg" {
  name        = var.eks_cluster_sg_name
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.eks_vpc.id

  tags = {
    Name = var.eks_cluster_sg_name
  }
}

resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the EKS cluster API"
  type                    = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  security_group_id       = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
}

resource "aws_security_group_rule" "cluster_ingress_kubelet" {
  description       = "Allow Kubelets to communicate with cluster"
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_cluster_sg.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group" "eks_node_sg" {
  name        = var.eks_node_sg_name
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.eks_vpc.id

  tags = {
    Name = var.eks_node_sg_name
  }
}

resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
}

resource "aws_security_group_rule" "node_egress_internet" {
  description       = "Allow nodes to communicate with internet"
  type             = "egress"
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks      = ["0.0.0.0/0"]
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "eks_subnet_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.subnet1_cidr
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "eks_subnet_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.subnet2_cidr
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "eks_subnet_3" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.subnet3_cidr
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = false
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  version = var.cluster_version

  vpc_config {
    subnet_ids               = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id, aws_subnet.eks_subnet_3.id]
    endpoint_private_access  = var.endpoint_private_access
    endpoint_public_access   = var.endpoint_public_access
    security_group_ids       = [aws_security_group.eks_cluster_sg.id]
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_key.arn
    }
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.service_ipv4_cidr
    ip_family = "ipv4"
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  upgrade_policy {
    support_type = "EXTENDED"
  }

  access_config {
    authentication_mode                       = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}

resource "aws_kms_key" "eks_key" {
  description = "EKS cluster encryption key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "eks_key_alias" {
  name          = var.kms_key_alias_name
  target_key_id = aws_kms_key.eks_key.key_id
}
