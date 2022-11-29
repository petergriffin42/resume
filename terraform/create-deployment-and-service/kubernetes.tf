terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.20.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }
  backend "s3" {
    bucket         = "resume-petergriffin-terraform-state"
    key            = "state/terraform-deployment.tfstate"
    region         = "us-west-2"
    encrypt        = true
    kms_key_id     = "alias/terraform-bucket-key"
    dynamodb_table = "terraform-state"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "resume-petergriffin-terraform-state"
    key    = "state/terraform-eks-cluster.tfstate"
    region = "us-west-2"
  }
}

# Retrieve EKS cluster information
provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "kubernetes_manifest" "clusterissuer_letsencrypt_production" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-production"
    }
    "spec" = {
      "acme" = {
        "email" = "pgriffwork@gmail.com"
        "privateKeySecretRef" = {
          "name" = "issuer-account-key"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "http01" = {
              "ingress" = {
                "class" = "nginx"
              }
            }
          },
        ]
      }
    }
  }
}

variable "dockerconfig" {
  sensitive = true
}

resource "kubernetes_secret" "dockercred" {
  metadata {
    name = "dockercred"
  }

  data = {
    ".dockerconfigjson" = base64decode(var.dockerconfig)
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_deployment" "resume-web" {
  metadata {
    name = "resume-web"
    labels = {
      App = "resume-web"
    }
  }

  spec {
    replicas = 4
    selector {
      match_labels = {
        App = "resume-web"
      }
    }
    template {
      metadata {
        labels = {
          App = "resume-web"
        }
      }
      spec {
        container {
          image             = "petergriffin42/resume:v1.8"
          image_pull_policy = "Always"
          name              = "resume-web-container"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
          }
        }
        image_pull_secrets {
          name = "dockercred"
        }
      }
    }
  }
}

resource "kubernetes_service" "resume-web-service" {
  metadata {
    name = "resume-web-service"
  }
  spec {
    selector = {
      App = "resume-web"
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "nginx-dmz" {
  wait_for_load_balancer = true
  metadata {
    name = "nginx-dmz"
    annotations = {
      "kubernetes.io/ingress.class"    = "nginx"
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
    }
  }
  spec {
    rule {
      host = "www.petergriffin.org"
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.resume-web-service.metadata.0.name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    tls {
      hosts       = ["www.petergriffin.org"]
      secret_name = "ingress-tls-cert"
    }
  }
}

# Display load balancer hostname (typically present in AWS)
output "load_balancer_hostname" {
  value = kubernetes_ingress_v1.nginx-dmz.status.0.load_balancer.0.ingress.0.hostname
}
