# Cloud & Terraform Homework — Session 19

Bibek Jyoti Charah — 24bcs10112 (GitHub: SammyUrfen)

Environment: Fedora 44, Terraform v1.16.1, AWS provider v6.67.0, random provider v3.9.1. No Kubernetes cluster is used.
AWS CLI v2 with an IAM user, region `ap-south-1`. Every command ran for real, including `plan`, `apply` and `destroy`.
All output is pasted as printed. Long output is cut with `...`. The 12-digit AWS account ID is replaced with
`<ACCOUNT_ID>` and my public IP with `<MY_IP>`.

| Task | Status |
|---|---|
| Terraform project (providers, variables, resources, outputs, dependencies) | Done |
| AWS resources created with `apply` and checked with curl and the AWS CLI | Done |
| Architecture diagram | Done (Mermaid) |
| `plan`, `apply`, `state list`, `output`, `destroy` | Done, output below |
| Screenshots | Terminal output pasted instead |
| All resources destroyed | Done, checked below |

## Architecture

```mermaid
flowchart TB
  user([Browser / SSH client]) -->|HTTP 80, SSH 22 from ssh_allowed_cidr| igw[Internet Gateway]
  subgraph aws[AWS ap-south-1]
    subgraph vpc[VPC 10.20.0.0/16]
      igw --> rt[Route table 0.0.0.0/0 to IGW]
      rt --> subnet
      subgraph subnet[Public subnet 10.20.1.0/24, ap-south-1a]
        ec2[EC2 t3.micro, Amazon Linux 2023, nginx hello page]
      end
      sg[Security group: 22 from one CIDR, 80 from anywhere] -.attached.- ec2
    end
    s3[(S3 bucket session19-artifacts-random, public access blocked)]
  end
```

## Files

| File | Contents |
|---|---|
| `provider.tf` | Terraform version, `aws` and `random` providers, region, default tags |
| `variables.tf` | Region, name prefix, CIDRs, instance type, SSH CIDR (validated), optional key pair |
| `main.tf` | VPC, subnet, IGW, route table + association, security group, AMI data source, EC2, S3 |
| `outputs.tf` | IDs, AMI, public IP, web URL, bucket name |
| `terraform.tfvars.example` | Sample values. Copy to `terraform.tfvars` (git-ignored) |

## Concepts

- **Providers.** A provider is a plugin that turns Terraform resources into API calls. `hashicorp/aws` talks to AWS.
  `hashicorp/random` makes a random suffix for the S3 bucket name, because bucket names are global.
  `init` downloads them and pins the versions in `.terraform.lock.hcl` (committed).
- **Variables.** Inputs in `variables.tf`. Region defaults to `ap-south-1`. `ssh_allowed_cidr` has no default,
  so you must set it. A validation block rejects `0.0.0.0/0` so SSH is never open to the world.
- **Resources.** Each `resource` block is one AWS object. `data "aws_ami"` is a read-only lookup: it finds the
  latest Amazon Linux 2023 AMI at plan time, so no region-specific AMI ID is hard-coded.
  `user_data` installs nginx on first boot and writes a hello page.
- **Outputs.** Values printed after `apply` (and by `terraform output`), for example the URL of the hello page.
- **Dependencies.** Terraform builds a graph and creates resources in order.
  - *Implicit:* a reference such as `vpc_id = aws_vpc.main.id` makes the subnet wait for the VPC. Most edges in the graph come from references.
  - *Explicit:* `aws_instance.web` has `depends_on = [aws_route_table_association.public]`. The instance block does not
    reference the route table, so without this Terraform could boot the instance before the subnet has an internet route.
    Then `dnf install nginx` in `user_data` fails and the page never appears.
  - `destroy` walks the same graph in reverse.
- **State.** After `apply`, Terraform writes `terraform.tfstate`: the map from each resource address to the real AWS ID.
  `plan` compares config, state and real AWS to find the changes. State can hold sensitive values, so `*.tfstate*`
  is git-ignored. A team would use a remote backend (S3 + locking); this homework keeps local state.

## Cost

All resources are free-tier or free: t3.micro (free-tier eligible in ap-south-1), VPC/subnet/IGW/route table/security
group (no charge), an empty S3 bucket. The public IPv4 address on the instance is billed hourly by AWS (about
USD 0.005/h) outside the free-tier allowance. No NAT gateway, no Elastic IP. **Run `terraform destroy` as soon as you
have checked the page.** `force_destroy = true` on the bucket lets destroy delete it even if it holds objects.

## Commands that ran (no AWS needed)

```
$ terraform version
Terraform v1.16.1
on linux_amd64

Your version of Terraform is out of date! The latest version
is 1.16.5. You can update by downloading from https://developer.hashicorp.com/terraform/install
```

```
$ terraform init
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Finding hashicorp/random versions matching "~> 3.6"...
- Installing hashicorp/aws v6.67.0...
- Installed hashicorp/aws v6.67.0 (signed by HashiCorp)
- Installing hashicorp/random v3.9.1...
- Installed hashicorp/random v3.9.1 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
...
```

```
$ terraform fmt -recursive
$ echo $?
0
```

(`fmt` printed no file names, so all files were already formatted.)

```
$ terraform validate
Success! The configuration is valid.
```

```
$ terraform graph
digraph G {
  rankdir = "RL";
  node [shape = rect, fontname = "sans-serif"];
  "data.aws_ami.al2023" [label="data.aws_ami.al2023"];
  "aws_instance.web" [label="aws_instance.web"];
  "aws_internet_gateway.main" [label="aws_internet_gateway.main"];
  "aws_route_table.public" [label="aws_route_table.public"];
  "aws_route_table_association.public" [label="aws_route_table_association.public"];
  "aws_s3_bucket.artifacts" [label="aws_s3_bucket.artifacts"];
  "aws_s3_bucket_public_access_block.artifacts" [label="aws_s3_bucket_public_access_block.artifacts"];
  "aws_security_group.web" [label="aws_security_group.web"];
  "aws_subnet.public" [label="aws_subnet.public"];
  "aws_vpc.main" [label="aws_vpc.main"];
  "random_id.bucket_suffix" [label="random_id.bucket_suffix"];
  "aws_instance.web" -> "data.aws_ami.al2023";
  "aws_instance.web" -> "aws_route_table_association.public";
  "aws_instance.web" -> "aws_security_group.web";
  "aws_internet_gateway.main" -> "aws_vpc.main";
  "aws_route_table.public" -> "aws_internet_gateway.main";
  "aws_route_table_association.public" -> "aws_route_table.public";
  "aws_route_table_association.public" -> "aws_subnet.public";
  "aws_s3_bucket.artifacts" -> "random_id.bucket_suffix";
  "aws_s3_bucket_public_access_block.artifacts" -> "aws_s3_bucket.artifacts";
  "aws_security_group.web" -> "aws_vpc.main";
  "aws_subnet.public" -> "aws_vpc.main";
}
```

Read an edge `A -> B` as "A depends on B". The edge `aws_instance.web -> aws_route_table_association.public`
is the explicit `depends_on`; the others come from references.

## Commands against AWS

```
$ aws sts get-caller-identity --query Arn --output text
arn:aws:iam::<ACCOUNT_ID>:user/SammyUrfen-CLI
```

### terraform plan

```
$ terraform plan -out=tfplan
data.aws_ami.al2023: Reading...
data.aws_ami.al2023: Read complete after 0s [id=ami-03054015e26069645]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.web will be created
  + resource "aws_instance" "web" {
      + ami                                  = "ami-03054015e26069645"
...
      + instance_type                        = "t3.micro"
...
  # aws_security_group.web will be created
  + resource "aws_security_group" "web" {
      + arn                    = (known after apply)
      + description            = "HTTP from anywhere, SSH only from ssh_allowed_cidr"
...
          + {
              + cidr_blocks      = [
                  + "<MY_IP>/32",
                ]
              + description      = "SSH from one trusted CIDR"
              + from_port        = 22
...
Plan: 10 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ami_id             = "ami-03054015e26069645"
  + instance_public_ip = (known after apply)
  + public_subnet_id   = (known after apply)
  + s3_bucket_name     = (known after apply)
  + security_group_id  = (known after apply)
  + vpc_id             = (known after apply)
  + web_url            = (known after apply)
...
```

The 10 resources: VPC, subnet, internet gateway, route table, route table association, security group, EC2
instance, `random_id`, S3 bucket, S3 public access block. The AMI lookup is a data source, so it is not counted.

### terraform apply

```
$ terraform apply -auto-approve tfplan
random_id.bucket_suffix: Creating...
random_id.bucket_suffix: Creation complete after 0s [id=H-fpPQ]
aws_vpc.main: Creating...
aws_s3_bucket.artifacts: Creating...
aws_vpc.main: Creation complete after 2s [id=vpc-0a3a4fdbcb83515a8]
aws_internet_gateway.main: Creating...
aws_subnet.public: Creating...
aws_security_group.web: Creating...
aws_s3_bucket.artifacts: Creation complete after 3s [id=session19-artifacts-1fe7e93d]
aws_s3_bucket_public_access_block.artifacts: Creating...
aws_s3_bucket_public_access_block.artifacts: Creation complete after 0s [id=session19-artifacts-1fe7e93d]
aws_internet_gateway.main: Creation complete after 2s [id=igw-02732e8b8b34ea4ba]
aws_route_table.public: Creating...
aws_route_table.public: Creation complete after 0s [id=rtb-0af451252a7a723aa]
aws_security_group.web: Creation complete after 3s [id=sg-0da37e1d3e743e83f]
aws_subnet.public: Still creating... [00m10s elapsed]
aws_subnet.public: Creation complete after 12s [id=subnet-091150b6037330a0c]
aws_route_table_association.public: Creating...
aws_route_table_association.public: Creation complete after 0s [id=rtbassoc-036ff6a8eb945c6a3]
aws_instance.web: Creating...
aws_instance.web: Still creating... [00m10s elapsed]
aws_instance.web: Creation complete after 13s [id=i-0c17cbcf5986274c2]

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

ami_id = "ami-03054015e26069645"
instance_public_ip = "65.2.124.100"
public_subnet_id = "subnet-091150b6037330a0c"
s3_bucket_name = "session19-artifacts-1fe7e93d"
security_group_id = "sg-0da37e1d3e743e83f"
vpc_id = "vpc-0a3a4fdbcb83515a8"
web_url = "http://ec2-65-2-124-100.ap-south-1.compute.amazonaws.com"
```

The order shows the dependency graph at work. The instance started only after the route table association
was complete (the explicit `depends_on`). The S3 bucket has no link to the network, so it was created in parallel.
The `Outputs:` block is the same as the output of `terraform output`.

### terraform state list

```
$ terraform state list
data.aws_ami.al2023
aws_instance.web
aws_internet_gateway.main
aws_route_table.public
aws_route_table_association.public
aws_s3_bucket.artifacts
aws_s3_bucket_public_access_block.artifacts
aws_security_group.web
aws_subnet.public
aws_vpc.main
random_id.bucket_suffix
```

### Hello page and AWS proof

The page answered on the 4th try (about 30 s after apply, while `user_data` installed nginx).

```
$ curl -s -i http://65.2.124.100 | head -3
HTTP/1.1 200 OK
Server: nginx/1.30.5
Date: Wed, 07 Oct 2026 17:20:57 GMT
$ curl -s http://65.2.124.100
<h1>Hello from session19 (Terraform, Session 19)</h1>
```

```
$ aws ec2 describe-instances --instance-ids i-0c17cbcf5986274c2 --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,ImageId]' --output table
-----------------------------------------------------------------------------------------
|                                   DescribeInstances                                   |
+----------------------+-----------+----------+---------------+-------------------------+
|  i-0c17cbcf5986274c2 |  t3.micro |  running |  65.2.124.100 |  ami-03054015e26069645  |
+----------------------+-----------+----------+---------------+-------------------------+
$ aws s3 ls | grep session19
2026-10-07 22:49:56 session19-artifacts-1fe7e93d
```

### terraform destroy

```
$ terraform destroy -auto-approve
random_id.bucket_suffix: Refreshing state... [id=H-fpPQ]
data.aws_ami.al2023: Reading...
aws_vpc.main: Refreshing state... [id=vpc-0a3a4fdbcb83515a8]
aws_s3_bucket.artifacts: Refreshing state... [id=session19-artifacts-1fe7e93d]
data.aws_ami.al2023: Read complete after 2s [id=ami-03054015e26069645]
...
Plan: 0 to add, 0 to change, 10 to destroy.
...
aws_s3_bucket_public_access_block.artifacts: Destroying... [id=session19-artifacts-1fe7e93d]
aws_instance.web: Destroying... [id=i-0c17cbcf5986274c2]
aws_s3_bucket_public_access_block.artifacts: Destruction complete after 1s
aws_s3_bucket.artifacts: Destroying... [id=session19-artifacts-1fe7e93d]
aws_s3_bucket.artifacts: Destruction complete after 1s
random_id.bucket_suffix: Destroying... [id=H-fpPQ]
random_id.bucket_suffix: Destruction complete after 0s
aws_instance.web: Destruction complete after 31s
aws_route_table_association.public: Destroying... [id=rtbassoc-036ff6a8eb945c6a3]
aws_security_group.web: Destroying... [id=sg-0da37e1d3e743e83f]
aws_route_table_association.public: Destruction complete after 0s
aws_subnet.public: Destroying... [id=subnet-091150b6037330a0c]
aws_route_table.public: Destroying... [id=rtb-0af451252a7a723aa]
aws_route_table.public: Destruction complete after 1s
aws_internet_gateway.main: Destroying... [id=igw-02732e8b8b34ea4ba]
aws_security_group.web: Destruction complete after 1s
aws_subnet.public: Destruction complete after 1s
aws_internet_gateway.main: Destruction complete after 0s
aws_vpc.main: Destroying... [id=vpc-0a3a4fdbcb83515a8]
aws_vpc.main: Destruction complete after 1s

Destroy complete! Resources: 10 destroyed.
```

Destroy ran in reverse order: the instance went first, and the VPC went last.

### Nothing is left

```
$ terraform state list | wc -l
0
$ aws ec2 describe-instances --instance-ids i-0c17cbcf5986274c2 --query 'Reservations[].Instances[].State.Name' --output text
terminated
$ aws ec2 describe-vpcs --filters Name=tag:Project,Values=session19 --query 'Vpcs[].VpcId' --output text
$ aws s3 ls | grep -c session19
0
```

A terminated instance stays visible for about an hour and costs nothing. No session19 VPC or bucket is left.

## Findings

The first `terraform plan` failed. The IAM user had no EC2 read permission:

```
$ terraform plan -out=tfplan
...
Plan: 9 to add, 0 to change, 0 to destroy.
Error: reading EC2 AMIs: operation error EC2: DescribeImages, https response error StatusCode: 403, RequestID: 44003b04-6e51-4473-95ea-4e9e1125ddfb, api error UnauthorizedOperation: You are not authorized to perform this operation. User: arn:aws:iam::<ACCOUNT_ID>:user/SammyUrfen-CLI is not authorized to perform: ec2:DescribeImages because no identity-based policy allows the ec2:DescribeImages action
```

Cause: the `aws_ami` data source calls `ec2:DescribeImages`, and the user had no policy that allows it.
The plan counted 9 resources because the instance needs the AMI ID. Nothing was created, because only `plan` ran.
Fix: attach `AmazonEC2FullAccess` and `AmazonS3FullAccess` to the IAM user. The next `plan` showed 10 resources.

Another small finding: `terraform version` warns that 1.16.1 is out of date (1.16.5 is the latest). It does not affect this project.

## How to run it again

1. Install the AWS CLI and run `aws configure` (access key of an IAM user, region `ap-south-1`). Check with `aws sts get-caller-identity`.
2. `cp terraform.tfvars.example terraform.tfvars` and set `ssh_allowed_cidr` to your IP: `echo "$(curl -s https://checkip.amazonaws.com)/32"`.
   Set `key_name` only if you made a key pair and want SSH.
3. `terraform init`, then `terraform plan -out=tfplan`, then `terraform apply tfplan`.
4. Wait 1–2 minutes for `user_data`, then open the `web_url` output. It should show "Hello from session19".
5. `terraform state list` to see what Terraform tracks.
6. **`terraform destroy`** and type `yes`. Check the EC2 console shows the instance as terminated.
