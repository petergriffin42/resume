# Peter Griffin's Resume!
This respository was an oppurtunity to learn and show off some of my knowledge while I was at it. 

I used the following while creating this respository:
* Hugo for creating the website
* Nginx docker container to host the website
* EKS cluster on AWS to run the nginx containers in Kubernetes
* Cert-manager to generate the TLS certificates from Let's Encrypt
* Terraform to automate the creation of the EKS cluster and Kubernetes resources
* AWS s3 bucket to hold the remote Terraform state files
* Github Actions to run the Terraform commands to create & configure the EKS cluster
