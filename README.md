# 🏰 TerraThrone — Highly Available AWS Infrastructure with Terraform

> Deploy a production-grade, auto-scaling web application on AWS using Infrastructure as Code (Terraform).

---

## 📌 Project Overview

**TerraThrone** is a Terraform project that provisions a fully automated, highly available AWS infrastructure to host a static web application (a Game of Thrones themed Zomato clone). The entire infrastructure — from networking to compute to monitoring — is defined as code and deployable with a single `terraform apply`.

This project is ideal for learning or demonstrating real-world DevOps concepts like multi-AZ deployments, auto-scaling, load balancing, and cloud notifications using AWS-native services.

---

## 🏗️ Architecture

```
                        ┌─────────────────────────────────────────┐
                        │                  AWS VPC                 │
                        │            CIDR: 10.0.0.0/16            │
                        │                                         │
                        │  ┌──────────────┐  ┌──────────────┐    │
              Internet  │  │  Public Sub  │  │  Public Sub  │    │
         ───────────►   │  │  (AZ: 1a)    │  │  (AZ: 1b)    │    │
                   ALB  │  │  10.0.1.0/24 │  │  10.0.2.0/24 │    │
                        │  └──────┬───────┘  └──────┬───────┘    │
                        │         │  NAT GW          │            │
                        │  ┌──────▼───────┐  ┌──────▼───────┐    │
                        │  │  Private Sub │  │  Private Sub │    │
                        │  │  (AZ: 1a)    │  │  (AZ: 1b)    │    │
                        │  │  10.0.3.0/24 │  │  10.0.4.0/24 │    │
                        │  │  EC2 (ASG)   │  │  EC2 (ASG)   │    │
                        │  └──────────────┘  └──────────────┘    │
                        └─────────────────────────────────────────┘
                                          │
                                    SNS Notifications
                                          │
                                    📧 Email Alerts
```

---

## ☁️ AWS Services Used

| Service | Purpose |
|---|---|
| **VPC** | Isolated network with public and private subnets across 2 AZs |
| **Internet Gateway** | Allows public subnets to communicate with the internet |
| **NAT Gateway** | Allows private subnet instances to reach the internet (e.g., for `yum` / `git`) |
| **Application Load Balancer (ALB)** | Distributes traffic across EC2 instances |
| **Auto Scaling Group (ASG)** | Maintains desired capacity, scales between 2–5 instances |
| **EC2 Launch Template** | Defines instance config and bootstraps the web app via `user_data` |
| **Security Groups** | Restricts traffic between ALB and EC2 instances |
| **SNS + Email Subscription** | Sends email alerts on instance launch/termination events |
| **Key Pair (TLS)** | Auto-generates RSA 4096-bit SSH key pair for EC2 access |

---

## 📁 Project Structure

```
.
├── main.tf          # Core infrastructure — VPC, subnets, ALB, ASG, SNS
├── variables.tf     # Input variables (region, instance type)
├── outputs.tf       # Output values (ALB DNS name)
└── README.md        # You are here
```

---

## ⚙️ Configuration

### Variables (`variables.tf`)

| Variable | Default | Description |
|---|---|---|
| `region` | `ap-south-1` | AWS region to deploy into |
| `instance_type` | `t3.micro` | EC2 instance type for ASG |

---

## 🚀 Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) v1.0+
- AWS CLI configured, or AWS credentials set as environment variables
- An AWS account with sufficient IAM permissions

### 1. Clone the Repository

```bash
git clone https://github.com/PriyeshPandey07/Terrafrom-Autoscaling-ALB-Project.git
cd terraformproject
```

### 2. Set AWS Credentials (Never hardcode these!)

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-south-1"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Preview the Plan

```bash
terraform plan
```

### 5. Deploy the Infrastructure

```bash
terraform apply
```

### 6. Access the Application

After apply completes, Terraform will output the ALB DNS name:

```
Outputs:
alb_dns = "project-alb-xxxxxxxxxx.ap-south-1.elb.amazonaws.com"
```

Open this URL in your browser to view the deployed web app.

### 7. Destroy the Infrastructure

```bash
terraform destroy
```

---

## 🌐 Networking Design

- **Public Subnets** (`10.0.1.0/24`, `10.0.2.0/24`) — host the ALB and NAT Gateway
- **Private Subnets** (`10.0.3.0/24`, `10.0.4.0/24`) — host EC2 instances (not directly internet-accessible)
- Traffic flows: `Internet → ALB (public) → EC2 (private)`
- Outbound traffic from EC2 flows through the NAT Gateway

---

## 📣 SNS Notifications

The project sets up an SNS topic and subscribes an email address to it. You will receive email alerts whenever:

- ✅ A new EC2 instance is **launched** by the ASG
- ❌ An EC2 instance is **terminated** by the ASG

> **Note:** After deployment, check your inbox and **confirm the SNS subscription** to start receiving alerts.

---

## 🔐 Security Notes

- AWS credentials should **never** be hardcoded in `main.tf`. Always use environment variables or IAM roles.
- The SSH ingress rule (`port 22`) is currently open to `0.0.0.0/0`. Since EC2 instances are in private subnets, this is not directly exploitable — but it is best practice to restrict this to a bastion host or VPN IP.
- The private key (`project-key.pem`) is generated locally by Terraform. Keep it secure and do not commit it to version control. Add it to `.gitignore`:

```
project-key.pem
*.tfstate
*.tfstate.backup
.terraform/
```

---

## 📊 Auto Scaling Configuration

| Parameter | Value |
|---|---|
| Minimum instances | 2 |
| Desired instances | 2 |
| Maximum instances | 5 |
| Health check type | ELB |
| Health check grace period | 30s *(recommend increasing to 300s)* |

---

## 🛠️ What the User Data Script Does

On every new instance launch, the bootstrap script automatically:

1. Installs `git` and `httpd` (Apache)
2. Starts and enables the Apache service
3. Clones the [Throne-game](https://github.com/PriyeshPandey07/Throne-game) web app from GitHub
4. Copies the app files to Apache's web root (`/var/www/html/`)

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you'd like to change.

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).

---

<p align="center">Built with ❤️ using Terraform & AWS</p>
