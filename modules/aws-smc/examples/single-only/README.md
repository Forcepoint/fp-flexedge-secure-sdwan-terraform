This example demonstrates the usage of Terraform for infrastructure provisioning. It includes instructions on how to create SSH keys using the `ssh-keygen` command and how to use the `terraform init` and `terraform apply` commands.

## Create SSH Keys

1. Run the following command to generate an SSH key pair:

ssh-keygen 

This will generate a new SSH key pair with the specified email address.

2. When prompted, specify the location to save the keys (default is usually fine) and enter a passphrase (optional).

3. Two files will be generated: `id_rsa` (private key) and `id_rsa.pub` (public key). The public key can be shared with remote servers for authentication.

## Initialize Terraform

1. Run the following command to initialize Terraform and download the necessary providers and modules:

terraform init

This will set up the working directory and prepare it for Terraform operations.

## Apply Terraform Changes

1. Run the following command to apply the Terraform configuration and create or update the infrastructure resources:

terraform apply

This will prompt you to confirm the execution of the changes. Enter `yes` to proceed.

2. Terraform will then provision the specified resources according to your configuration.

3. Once the process is complete, Terraform will display the created resources and any relevant output.


