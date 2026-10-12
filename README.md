# Terraform + Database Reliability Assessment

A production-grade, plan-first AWS infrastructure implementation and locally verifiable PostgreSQL reliability framework.

---

## Architecture Overview

```text
                             [ Internet ]
                                  │
                                  ▼
                   ┌──────────────────────────────┐
                   │  Application Load Balancer   │ (Public Subnets: AZ-a, AZ-b)
                   └──────────────┬───────────────┘
                                  │ Port 80 (HTTP)
                                  ▼
                   ┌──────────────────────────────┐
                   │    ECS Fargate Tasks         │ (Private Subnets: AZ-a, AZ-b)
                   │  (Nginx Container Service)   │ (assign_public_ip = false)
                   └──────────────┬───────────────┘
                                  │ Port 5432 (PostgreSQL)
                                  ▼
                   ┌──────────────────────────────┐
                   │     Amazon RDS PostgreSQL    │ (Private Subnets: DB Subnet Group)
                   │   (Storage Encrypted, gp3)   │ (publicly_accessible = false)
                   └──────────────────────────────┘
```

### Network Architecture & Traffic Flow
- **VPC**: Dedicated IPv4 CIDR with DNS support and DNS hostnames enabled.
- **Subnets**: 2 public subnets and 2 private subnets distributed across 2 Availability Zones (`ap-south-1a`, `ap-south-1b`).
- **Egress Routing**:
  - Public subnets route `0.0.0.0/0` via the Internet Gateway (IGW).
  - Private subnets route `0.0.0.0/0` via NAT Gateway(s).
  - **Dev**: Cost-conscious single NAT Gateway shared across private subnets.
  - **Prod**: High-availability multi-AZ NAT Gateways (one per public subnet/AZ).
- **Security Group Isolation**:
  - **ALB Security Group**: Accepts HTTP (port 80) from client CIDRs (`0.0.0.0/0`).
  - **ECS Task Security Group**: Accepts port 80 **strictly from the ALB Security Group** (no direct internet ingress).
  - **RDS Security Group**: Accepts port 5432 **strictly from the ECS Task Security Group** (no public access, no internet route).

---

## Repository Structure

```text
.
├── .env.example                          # Environment variable template for local database
├── .gitignore                            # Excludes state files, plan dumps, secrets, and backups
├── docker-compose.yml                    # Local PostgreSQL 16 container definition with healthchecks
├── README.md                             # Comprehensive technical documentation and audit report
├── .github/
│   └── workflows/
│       └── terraform.yml                 # CI pipeline: Terraform fmt/init/validate/plan + DB & backup tests
├── database/
│   ├── migrations/
│   │   └── 001_schema.sql                # DDL: hotel_bookings, booking_events, constraints & indexes
│   └── seed.sql                          # Deterministic DML: 120 bookings and 80 booking events
├── infra/
│   ├── envs/
│   │   ├── dev/                          # Dev environment definition
│   │   │   ├── backend.tf                # Local backend configuration (migratable to S3)
│   │   │   ├── dev.backend.hcl.example   # Documented S3 remote backend template
│   │   │   ├── dev.tfvars                # Cost-conscious dev variables
│   │   │   ├── main.tf                   # Root module calling network, ecs, and rds
│   │   │   ├── outputs.tf                # ALB DNS, RDS endpoint and port
│   │   │   └── variables.tf              # Environment variable definitions
│   │   └── prod/                         # Prod environment definition
│   │       ├── backend.tf                # Isolated local backend configuration
│   │       ├── prod.backend.hcl.example  # Production S3 remote backend template with state locking
│   │       ├── prod.tfvars               # Highly available, hardened prod variables
│   │       ├── main.tf                   # Root module calling network, ecs, and rds
│   │       ├── outputs.tf                # ALB DNS, RDS endpoint and port
│   │       └── variables.tf              # Environment variable definitions
│   └── modules/
│       ├── network/                      # VPC, Subnets, IGW, NAT GW, Route Tables
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   └── variables.tf
│       ├── ecs/                          # ALB, Target Group, ECS Fargate Service, IAM, CloudWatch
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   └── variables.tf
│       └── rds/                          # RDS PostgreSQL, DB Subnet Group, Security Groups
│           ├── main.tf
│           ├── outputs.tf
│           └── variables.tf
└── scripts/
    ├── backup.sh                         # Atomic pg_dump script (custom format, error handling)
    └── restore.sh                        # Clean pg_restore script with row count verification
```

---

## Environment Comparison Matrix

| Configuration Attribute | Dev (`infra/envs/dev`) | Prod (`infra/envs/prod`) | Rationale |
|---|---|---|---|
| **VPC CIDR** | `10.10.0.0/16` | `10.20.0.0/16` | Non-overlapping CIDRs for peering / transit routing |
| **NAT Gateway Strategy** | Single NAT Gateway (`single_nat_gateway = true`) | Multi-AZ NAT Gateways (`single_nat_gateway = false`) | Minimizes hourly NAT GW charges in Dev; avoids single-point-of-failure in Prod |
| **ECS Task Sizing** | 256 CPU / 512 MiB | 512 CPU / 1024 MiB | Right-sized for dev workloads; higher throughput in Prod |
| **ECS Desired Count** | 1 | 2 (across distinct AZs) | Zero-redundancy dev; high availability and zero-downtime rollouts in Prod |
| **RDS Instance Class** | `db.t4g.micro` | `db.t4g.small` | Cost-effective burstable dev; dedicated headroom in Prod |
| **RDS Allocated Storage** | 20 GiB (gp3) | 50 GiB (gp3) | Reduced base cost in Dev; higher initial capacity in Prod |
| **Multi-AZ Replication** | Disabled (`false`) | Enabled (`true`) | Cuts dev RDS cost by 50%; synchronous standby in Prod |
| **Backup Retention** | 3 days | 14 days | Minimal dev storage; extended audit recovery window in Prod |
| **Deletion Protection** | Disabled (`false`) | Enabled (`true`) | Allows tear-down in Dev; prevents accidental drop in Prod |
| **Final DB Snapshot** | Skipped (`skip_final_snapshot = true`) | Created (`final_snapshot_identifier = ...`) | Fast lifecycle in Dev; regulatory compliance in Prod |

---

## 1. Local Database Setup & Reset

### Prerequisites
- Docker Engine and Docker Compose v2
- Bash shell (WSL, Git Bash, or Linux/macOS terminal)

### Starting the Database
1. Copy the environment configuration:
   ```bash
   cp .env.example .env
   ```
2. Launch the PostgreSQL service:
   ```bash
   docker compose up -d
   docker compose ps
   ```
3. PostgreSQL automatically initializes and executes:
   - `database/migrations/001_schema.sql` (Tables, constraints, and indexes)
   - `database/seed.sql` (Deterministic dataset)

### Resetting the Database Safely
To completely reset the database and force re-execution of schema and seeds:
```bash
docker compose down -v
docker compose up -d
```

### Verifying Seed Data
```bash
docker compose exec -T db psql -U app -d bookings -c "SELECT COUNT(*) AS bookings FROM hotel_bookings;"
# Expected: 120

docker compose exec -T db psql -U app -d bookings -c "SELECT COUNT(*) AS events FROM booking_events;"
# Expected: 80

docker compose exec -T db psql -U app -d bookings -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename='hotel_bookings';"
```

---

## 2. Query Optimization & Indexing Strategy

### The Target Query
```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

### The Optimal Index Strategy
```sql
CREATE INDEX idx_hotel_bookings_city_created_org_status
    ON hotel_bookings (city, created_at, org_id, status)
    INCLUDE (amount);
```

### Technical Rationale & Deep Dive

1. **Column Ordering `(city, created_at, ...)`**:
   - **Equality filter first (`city`)**: Placing `city` at the leading position narrows the B-Tree search space immediately to only the entries matching the equality condition (`city = 'delhi'`).
   - **Range filter second (`created_at`)**: Within the subset of `'delhi'` entries, the B-Tree can perform a contiguous slice scan from `NOW() - INTERVAL '30 days'` to the end of the branch. Range filters stop multi-column B-tree equality matching for subsequent keys, so range columns must always follow equality columns.
2. **Grouping Keys `(org_id, status)`**:
   - Including `org_id` and `status` in the index key allows PostgreSQL to read pre-sorted data directly from the index. In large datasets, this enables either an efficient HashAggregate or a pre-sorted Stream/GroupAggregate without an external disk/memory sort.
3. **Covering Index with `INCLUDE (amount)`**:
   - The query calculates `SUM(amount)`. By appending `amount` as an unindexed payload column via PostgreSQL's `INCLUDE` clause:
     - The column does not increase B-Tree key depth or intermediate node size.
     - Every column referenced in the query (`city`, `created_at`, `org_id`, `status`, `amount`) is resident inside the index page.
     - This unlocks **Index-Only Scans** with `Heap Fetches: 0` when the table visibility map is up-to-date.
4. **Why PostgreSQL Optimizer Chooses Sequential Scan on Small Data**:
   - With 120 seed rows, the entire `hotel_bookings` table occupies only **2 disk buffer pages** (`shared hit=2`).
   - A sequential scan cost estimate is `4.40`.
   - An index-only scan requires reading index root pages, leaf pages, visibility map pages, and evaluating index conditions, producing an estimate of `4.43`.
   - PostgreSQL's cost-based optimizer correctly evaluates `4.40 < 4.43` and selects a sequential scan. This is an intentional and correct decision by the planner, not a defect in the index.
5. **Plan Demonstration (`EXPLAIN (ANALYZE, BUFFERS)`)**:
   - When table size grows or when `SET enable_seqscan = off;` is toggled after `VACUUM ANALYZE`:
     ```text
     HashAggregate (cost=4.57..4.68 rows=9 width=65) (actual time=0.099..0.102 rows=4 loops=1)
       Group Key: org_id, status
       -> Index Only Scan using idx_hotel_bookings_city_created_org_status on hotel_bookings
            (cost=0.15..4.43 rows=14 width=31) (actual time=0.068..0.070 rows=14 loops=1)
            Index Cond: ((city = 'delhi'::text) AND (created_at >= (now() - '30 days'::interval)))
            Heap Fetches: 0
            Buffers: shared hit=5
     ```

---

## 3. Database Backup & Restore

The backup and restore operations are automated via robust, POSIX-compliant Bash scripts located in `scripts/`.

### Backup Execution (`scripts/backup.sh`)
- Uses PostgreSQL custom format (`pg_dump -Fc`), which is compressed and supports selective parallel restore.
- Uses atomic writes: dumps to a `.tmp` file first and renames upon validation (`test -s`).
- Implements `trap cleanup EXIT ERR` to automatically delete empty or incomplete files if `pg_dump` fails.
- Never prints passwords or database credentials to stdout/stderr.
- Returns a non-zero exit code on failure.

Run backup:
```bash
./scripts/backup.sh
```
*Output:*
```text
Creating backup for database 'bookings' from service 'db'...
Backup created successfully: backups/bookings_20261012_121054.dump (8920 bytes)
```

### Restore Execution (`scripts/restore.sh`)
- Automatically discovers the latest valid, non-empty backup file in `backups/` or accepts `BACKUP_FILE=<path>`.
- Terminates active connections to the target database via `pg_terminate_backend`.
- Drops and recreates a clean target database (`bookings_restore`).
- Executes `pg_restore --exit-on-error` to ensure zero tolerance for partial restorations.
- Queries both source and target databases and outputs an automated row-count reconciliation table.

Run restore:
```bash
./scripts/restore.sh
```
*Output:*
```text
Selected backup for restore: backups/bookings_20261012_121054.dump (8920 bytes)
Target restore database: 'bookings_restore' on service 'db'
DROP DATABASE
CREATE DATABASE
Restoring database dump into 'bookings_restore'...
Restore completed successfully.
Verifying row counts between source ('bookings') and target ('bookings_restore')...

Table                | Source Rows  | Restored     | Match?  
---------------------+--------------+--------------+---------
hotel_bookings       | 120          | 120          | YES     
booking_events       | 80           | 80           | YES     

Verification passed: All tables and records match exactly.
```

---

## 4. Terraform Infrastructure Validation

The Terraform configurations are structured to allow full local initialization, validation, and plan generation without live AWS credentials or cloud provisioning.

### Plan-Only Validation Mechanism
In `infra/envs/dev` and `infra/envs/prod`, `variables.tf` defines `plan_only = true`. When active:
- Provider credentials use placeholder tokens.
- AWS metadata API checks, account ID lookups, and credential validations are skipped (`skip_credentials_validation = true`, `skip_requesting_account_id = true`, `skip_metadata_api_check = true`).
- Reviewers can generate complete execution plans (`terraform plan -refresh=false`) completely offline.
- **Safety Rule**: Never run `terraform apply` with `plan_only = true`.

### Validating Dev Environment
```bash
cd infra/envs/dev
terraform fmt -check
terraform init -input=false
terraform validate
terraform plan -refresh=false -input=false -no-color -var-file=dev.tfvars
```
*Result:* `Plan: 28 to add, 0 to change, 0 to destroy.`

### Validating Prod Environment
```bash
cd infra/envs/prod
terraform fmt -check
terraform init -input=false
terraform validate
terraform plan -refresh=false -input=false -no-color -var-file=prod.tfvars
```
*Result:* `Plan: 31 to add, 0 to change, 0 to destroy.`

---

## 5. State Management & Remote Backend Strategy

### Current Assessment Setup (Isolated Local State)
For local testing and offline evaluation:
- Both `dev` and `prod` define `backend "local"` inside their respective `backend.tf` files.
- Each environment maintains an isolated local state (`terraform.tfstate`) in its own directory, preventing state collision.
- State files and `.tfplan` files are strictly excluded from version control via `.gitignore`.

### Production Remote Backend Architecture
For multi-engineer teams and automated CI/CD pipelines, state must be migrated to AWS S3:

1. **S3 Bucket Configuration**:
   - **Versioning**: Enabled to protect against state corruption and enable point-in-time state rollback.
   - **Encryption**: Server-side encryption using AWS KMS (`aws:kms`) or AES256 (`aws:s3`).
   - **Access Control**: S3 Block Public Access enabled on all four settings; bucket policy enforcing TLS (`aws:SecureTransport = true`).
2. **State Locking**:
   - **DynamoDB Locking (Terraform < 1.10)**: DynamoDB table with primary key `LockID` (String).
   - **Native S3 Locking (Terraform >= 1.10)**: Native conditional write locking using `use_lockfile = true`.
3. **Migration Steps**:
   - Review and customize `infra/envs/dev/dev.backend.hcl.example` and `infra/envs/prod/prod.backend.hcl.example`.
   - Update `backend.tf`:
     ```terraform
     terraform {
       backend "s3" {}
     }
     ```
   - Initialize and migrate state:
     ```bash
     terraform init -backend-config=dev.backend.hcl -migrate-state
     ```

---

## 6. GitHub Actions CI Pipeline

The CI pipeline is defined in `.github/workflows/terraform.yml` and triggers on `push` to `main`, all `pull_request` events, and manual dispatch.

### Pipeline Structure
1. **Job 1: `terraform` (Matrix: `dev`, `prod`)**:
   - Pins Terraform version to `1.8.5` via `hashicorp/setup-terraform@v3` (`terraform_wrapper: false`).
   - Runs `terraform fmt -check -recursive`.
   - Runs `terraform init -input=false`.
   - Runs `terraform validate`.
   - Generates plan with `terraform plan -refresh=false -input=false -no-color -var-file=${{ matrix.environment }}.tfvars`.
   - Publishes the plan output as a downloadable GitHub Actions workflow artifact (`actions/upload-artifact@v4`).
2. **Job 2: `database-and-scripts`**:
   - Verifies shell script syntax using `bash -n scripts/backup.sh` and `bash -n scripts/restore.sh`.
   - Validates Compose syntax via `docker compose config`.
   - Boots PostgreSQL container, waits for healthy state, and checks SQL row counts.
   - Executes the reporting query with `EXPLAIN (ANALYZE, BUFFERS)`.
   - Executes `./scripts/backup.sh` and `./scripts/restore.sh` end-to-end to verify row count matching in CI.
   - Cleans up Compose services and volumes.

---

## 7. Security & Cost Considerations

### Security Guardrails
- **Zero-Trust Network Perimeter**: No database port is exposed to the public internet. RDS accepts traffic only from the ECS task security group.
- **Data Encryption**:
  - In-transit: ALB should terminate TLS with an ACM certificate (placeholder port 80 used for assessment; production requires port 443 with redirect).
  - At-rest: RDS storage encryption is enabled (`storage_encrypted = true`).
- **Secret Management**:
  - Master database credentials use `sensitive = true` in Terraform.
  - Production recommendation: Store database credentials in AWS Secrets Manager and inject them into ECS task definitions via task execution role IAM permissions.
- **Least-Privilege IAM**: ECS execution role attaches only `AmazonECSTaskExecutionRolePolicy`, allowing image pull and CloudWatch log streaming.

### Cost Optimization
- **NAT Gateway Economics**: An AWS NAT Gateway costs ~$0.045/hour (~$32.40/month) plus data processing charges.
  - Dev uses a single NAT Gateway across AZs (`single_nat_gateway = true`), saving >$32/month per additional AZ.
  - Prod uses multi-AZ NAT Gateways to prioritize uptime and fault tolerance across AZ boundaries.
- **Fargate Task Rightsizing**: Task CPU and memory are parameterized to avoid overprovisioning idle resources in non-production tiers.
- **Storage Autoscaling**: RDS uses `max_allocated_storage = 100` with initial 20 GiB / 50 GiB allocations, scaling dynamically without paying for unallocated disk space upfront.

---

## 8. Verification Audit Log

| Verification Check | Target / Command | Status | Notes / Output |
|---|---|---|---|
| **Terraform Formatting** | `terraform fmt -check -recursive .` | **PASSED** | Clean exit; all files formatted to standard HCL. |
| **Dev Terraform Validate** | `infra/envs/dev validate` | **PASSED** | "Success! The configuration is valid." |
| **Dev Terraform Plan** | `infra/envs/dev plan -refresh=false` | **PASSED** | 28 resources planned to add; outputs verified. |
| **Prod Terraform Validate** | `infra/envs/prod validate` | **PASSED** | "Success! The configuration is valid." |
| **Prod Terraform Plan** | `infra/envs/prod plan -refresh=false` | **PASSED** | 31 resources planned to add; outputs verified. |
| **Docker Compose Config** | `docker compose config` | **PASSED** | Valid Compose specification. |
| **PostgreSQL Health** | Container health check | **PASSED** | `pg_isready` reports healthy. |
| **Database Migrations** | `001_schema.sql` | **PASSED** | Tables, constraints, and composite indexes applied. |
| **Deterministic Seeds** | `seed.sql` | **PASSED** | 120 bookings, 80 booking events verified. |
| **Query Optimization** | `EXPLAIN (ANALYZE, BUFFERS)` | **PASSED** | Seq Scan verified for small dataset; Index-Only Scan verified with `enable_seqscan = off` (Heap Fetches: 0). |
| **Shell Syntax** | `bash -n scripts/*.sh` | **PASSED** | Both backup and restore scripts pass syntax validation. |
| **Backup Script** | `./scripts/backup.sh` | **PASSED** | Created 8,920 byte custom-format dump atomically. |
| **Restore Script** | `./scripts/restore.sh` | **PASSED** | Restored into `bookings_restore`; 120 / 80 rows matched. |
| **AWS Cloud Apply** | `terraform apply` | **NOT RUN** | Intentionally skipped per assessment specification. |
