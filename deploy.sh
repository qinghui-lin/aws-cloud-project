#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${PROJECT_DIR}/terraform"
ANSIBLE_DIR="${PROJECT_DIR}/ansible"
KEY_PATH="${TERRAFORM_DIR}/aws-pfe-key.pem"

usage() {
    echo "Usage: $0 {up|down|status}"
    exit 1
}

deploy_up() {
    echo "== AWS infrastructure provisioning (Terraform)... =="

    cd "${TERRAFORM_DIR}"
    terraform init -input=false
    terraform apply -auto-approve -input=false

    PUBLIC_IP=$(terraform output -raw server_public_ip)

    echo "== Generating Ansible inventory.ini... =="

    cat << INV > "${ANSIBLE_DIR}/inventory.ini"
[webservers]
${PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${KEY_PATH}
INV

    echo "== Waiting for SSH availability... =="
    sleep 15

    echo "== Configuring server and Docker deployment (Ansible)..."
    cd "${ANSIBLE_DIR}"
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml

    echo "== Deployment complete, application available on ${PUBLIC_IP}. =="
}

deploy_down() {
    echo "== Destroying AWS infrastructure... =="

    cd "${TERRAFORM_DIR}"
    terraform destroy -auto-approve -input=false
    rm -f "${ANSIBLE_DIR}/inventory.ini"

    echo "== Infrastructure destroyed and inventory cleared. =="
}

deploy_status() {
    cd "${TERRAFORM_DIR}"
    terraform state list || echo "No active resource."
}

case "${1:-}" in
    up)     deploy_up;;
    down)   deploy_down;;
    status) deploy_status;;
    *)      usage;;
esac
