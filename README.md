# MSPR TPRE961 — PoC Infrastructure K3s

Proof of Concept d'une infrastructure Kubernetes en Infrastructure as Code pour le projet scolaire MSPR TPRE961 (EPSI).

Déploiement d'un cluster K3s local sur 3 VMs KVM avec l'ERP Odoo 18 LTS accessible en HTTPS via Traefik.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  WSL2 Debian Trixie (hôte)                          │
│                                                     │
│  ┌─── libvirt NAT 192.168.100.0/24 ───────────────┐│
│  │                                                 ││
│  │  control-plane      worker-1       worker-2     ││
│  │  .10 (2c/3G/20G)   .11 (2c/4G/30G) .12         ││
│  │  K3s server         K3s agent      K3s agent    ││
│  │  Traefik v3                                     ││
│  │                                                 ││
│  │       ┌─────────────────────────┐               ││
│  │       │  Odoo 18 LTS (Bitnami) │               ││
│  │       │  PostgreSQL 17          │               ││
│  │       └─────────────────────────┘               ││
│  └─────────────────────────────────────────────────┘│
│                                                     │
│  https://odoo.local ──► Traefik Ingress (TLS)       │
└─────────────────────────────────────────────────────┘
```

## Stack technologique

| Composant | Version |
|-----------|---------|
| Hyperviseur | KVM/libvirt (QEMU 10.x) |
| IaC infrastructure | Terraform v1.15.5 (provider dmacvicar/libvirt v0.7.6) |
| IaC configuration | Ansible Core v2.20.4 |
| Kubernetes | K3s v1.33.12+k3s1 |
| Packaging K8s | Helm v4.1.4 |
| Applicatif | Odoo 18.0 (chart Bitnami 28.2.10) |
| Ingress | Traefik v3.6.13 (natif K3s) + certificat TLS autosigné |
| Image VM | Ubuntu 22.04.5 LTS (cloud image) |

## Prérequis système

- **OS** : WSL2 avec Debian Trixie (ou distribution Linux compatible)
- **RAM** : 15 Go minimum (11 Go alloués aux VMs)
- **CPU** : 6 coeurs minimum (6 vCPU alloués aux VMs)
- **Disque** : 80 Go libres minimum
- **Virtualisation imbriquée** : activée dans WSL2 (`/dev/kvm` doit exister)
- **Logiciels requis** :
  - `libvirt-daemon-system`, `qemu-system-x86`, `virtinst`
  - `terraform` >= 1.15.0
  - `ansible-core` >= 2.20
  - `helm` >= 4.1.0
  - `kubectl`
  - `git`, `curl`, `openssh-client`

### Activation de la virtualisation imbriquée (WSL2)

Créer ou éditer `%USERPROFILE%\.wslconfig` sous Windows :

```ini
[wsl2]
nestedVirtualization=true
memory=15GB
processors=12
```

Puis redémarrer WSL : `wsl --shutdown` dans PowerShell.

## Déploiement pas-à-pas

### Phase 0 — Préparation de l'environnement

```bash
# Installer les dépendances système
sudo apt update
sudo apt install -y libvirt-daemon-system libvirt-clients qemu-system-x86 \
  virtinst bridge-utils cloud-image-utils genisoimage curl git python3

# Démarrer libvirtd
sudo usermod -aG libvirt,kvm $USER
sudo systemctl enable --now libvirtd
virsh list --all

# Installer Terraform 1.15.5
curl -fSL https://releases.hashicorp.com/terraform/1.15.5/terraform_1.15.5_linux_amd64.zip -o /tmp/terraform.zip
unzip -o /tmp/terraform.zip -d /tmp && sudo mv /tmp/terraform /usr/bin/terraform

# Installer Helm 4.1.4
curl -fSL https://get.helm.sh/helm-v4.1.4-linux-amd64.tar.gz -o /tmp/helm.tar.gz
tar xzf /tmp/helm.tar.gz -C /tmp && sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm

# Générer une clé SSH (si absente)
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# Télécharger l'image Ubuntu 22.04 cloud
sudo mkdir -p /var/lib/libvirt/images
sudo wget -O /var/lib/libvirt/images/jammy-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

### Phase 1 — Provisionnement des VMs (Terraform)

```bash
cd terraform

# Créer terraform.tfvars avec votre clé SSH publique
echo 'ssh_public_key = "'$(cat ~/.ssh/id_ed25519.pub)'"' > terraform.tfvars

# Provisionner les VMs
terraform init
terraform apply -auto-approve

# Vérifier
virsh list --all
ssh debian@192.168.100.10   # control-plane
ssh debian@192.168.100.11   # worker-1
ssh debian@192.168.100.12   # worker-2
```

### Phase 2 — Déploiement K3s (Ansible)

```bash
cd ../ansible

# Installer K3s sur le control-plane et configurer kubectl localement
ansible-playbook -i inventory.ini k3s-install.yml

# Rejoindre les workers au cluster
ansible-playbook -i inventory.ini k3s-workers.yml

# Vérifier le cluster (depuis l'hôte)
kubectl get nodes
```

Les 3 noeuds doivent apparaître en état `Ready`.

### Phase 3 — Déploiement Odoo (Helm)

```bash
# Déployer Odoo 18 via Helm et configurer /etc/hosts
ansible-playbook -i inventory.ini deploy-odoo.yml

# Vérifier les pods
kubectl get pods -A

# Vérifier l'ingress
kubectl get ingress -A

# Tester l'accès HTTPS (certificat autosigné)
curl -sk https://odoo.local
```

### Accès à Odoo

- **URL** : https://odoo.local (accepter l'avertissement du certificat autosigné)
- **Email** : `user@example.com`
- **Mot de passe** :

```bash
kubectl get secret odoo -o jsonpath="{.data.odoo-password}" | base64 -d
```

## Destruction de l'infrastructure

```bash
# Supprimer le déploiement Odoo
helm uninstall odoo -n default

# Détruire les VMs et le réseau libvirt
cd terraform
terraform destroy -auto-approve

# Nettoyer les PVC restants
kubectl delete pvc --all -n default
```

## Workflow Git

```
main ← PR ← dev ← PR ← feature/*
```

- **`main`** : branche stable, uniquement via Pull Request approuvée depuis `dev`
- **`dev`** : branche d'intégration, reçoit les merges des branches de feature
- **`feature/*`** : branches de travail individuelles

| Branche | Phase | Description |
|---------|-------|-------------|
| `feature/terraform-vms` | Phase 1 | Provisionnement des 3 VMs KVM |
| `feature/k3s-install` | Phase 2 | Installation du cluster K3s |
| `feature/deploy-odoo` | Phase 3 | Déploiement Odoo 18 + Ingress TLS |
| `feature/readme-finalization` | Phase 4 | Documentation et finalisation |

## Notes sur les images Bitnami

Depuis août 2025, les images Docker Bitnami officielles (`docker.io/bitnami/*`) ont été retirées du Docker Hub public. Le déploiement utilise les images `bitnamilegacy/*` avec le flag `global.security.allowInsecureImages: true` dans les values Helm. Pour un déploiement en production, un abonnement Bitnami Secure Images est recommandé.

## Dépannage

### Les VMs ne démarrent pas

- Vérifier que `/dev/kvm` existe et est accessible
- Vérifier que `libvirtd` est actif : `sudo systemctl status libvirtd`
- Vérifier `nestedVirtualization=true` dans `.wslconfig` (Windows)

### K3s ne démarre pas

- Vérifier que le swap est désactivé : `free -h` (Swap doit être à 0)
- Consulter les logs : `sudo journalctl -u k3s -f` (sur le control-plane)

### Odoo ImagePullBackOff

Les images `docker.io/bitnami/*` ne sont plus disponibles. Utiliser `bitnamilegacy/*` dans les values Helm avec `global.security.allowInsecureImages: true`.

### Impossible d'accéder à https://odoo.local

1. Vérifier `/etc/hosts` : `grep odoo /etc/hosts` (doit pointer vers `192.168.100.10`)
2. Vérifier l'ingress : `kubectl get ingress -A`
3. Vérifier que Traefik est Running : `kubectl get pods -n kube-system`
4. Le certificat est autosigné : accepter l'avertissement du navigateur

### Odoo met du temps à démarrer

La première initialisation installe les modules Odoo et crée la base de données PostgreSQL. Cela peut prendre 5 à 10 minutes. Surveiller les logs avec `kubectl logs -f -l app.kubernetes.io/name=odoo`.

## Structure du projet

```
mspr-tpre961/
├── .gitignore
├── README.md
├── terraform/
│   ├── main.tf                    # Provisionnement des VMs libvirt
│   ├── variables.tf               # Variables Terraform
│   ├── outputs.tf                 # IPs des VMs en sortie
│   └── cloud-init/
│       ├── control-plane.yml      # Cloud-init du control-plane
│       ├── worker.yml             # Cloud-init des workers
│       └── network-config.yml     # Configuration réseau statique
├── ansible/
│   ├── inventory.ini              # Inventaire Ansible des VMs
│   ├── group_vars/
│   │   └── all.yml                # Variables globales du cluster
│   ├── k3s-install.yml            # Installation K3s server + kubeconfig
│   ├── k3s-workers.yml            # Jointure des workers au cluster
│   └── deploy-odoo.yml            # Déploiement Odoo + Ingress TLS
└── secrets/                       # EXCLU du Git (.gitignore)
```
