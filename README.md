# llm-gateway

`llm-gateway` is a personal sandbox for experimenting with AI service exposure, lightweight gateway patterns, and deployment workflows. The goal of the project is to explore how LLM-backed capabilities can be exposed through a simple API layer and supported with practical infrastructure tooling.

## About this project

This project is a personal sandbox for experimenting with how AI capabilities can be exposed through a simple service interface and supported with practical deployment infrastructure. It combines a lightweight FastAPI gateway with Kubernetes manifests and Terraform configuration to model a small but realistic AI service stack.

The focus is not just on calling an LLM API, but on understanding the surrounding engineering concerns: service boundaries, configuration, deployment, infrastructure layout, and operational readiness. It is intended as a hands-on workspace for testing ideas, learning patterns, and sharing implementation progress publicly.

## Repository layout

- `App/`: application code, container image definition, Python dependencies, and Kubernetes manifests
- `Infra/foundation/`: Terraform for shared foundation resources
- `Infra/platform/`: Terraform for platform-specific resources
- [ARCHITECTURE.md](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/ARCHITECTURE.md:1): system and deployment diagrams

## Application

The API service lives in [App/app/main.py](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/App/app/main.py:1) and currently exposes a minimal gateway interface for experimenting with AI-backed request handling:

- `POST /ask`: sends a prompt to the configured OpenAI model and returns the generated text
- `GET /healthz`: simple health check endpoint

### Request and response

`POST /ask`

Request body:

```json
{
  "prompt": "Explain what this service does."
}
```

Successful response:

```json
{
  "answer": "..."
}
```

Health check response:

```json
{
  "status": "healthy"
}
```

## Configuration

The application reads the following environment variables:

- `OPENAI_API_KEY`: required; used to authenticate to OpenAI
- `OPENAI_MODEL`: optional; defaults to `gpt-4.1`

If `OPENAI_API_KEY` is missing, `POST /ask` returns HTTP `500`.

If the OpenAI request fails or no text output is returned, the service responds with HTTP `502`.

## Local development

### Prerequisites

- Python 3.10+
- An OpenAI API key

### Install dependencies

```bash
cd App
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Start the API locally

```bash
cd App
export OPENAI_API_KEY=your_api_key_here
export OPENAI_MODEL=gpt-4.1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The service will be available at `http://localhost:8000`.

If you prefer not to activate the virtual environment, you can run:

```bash
cd App
OPENAI_API_KEY=your_api_key_here OPENAI_MODEL=gpt-4.1 .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Test locally

Open a second terminal after the server starts and run the checks below.

#### 1. Verify the service is up

Health check:

```bash
curl http://localhost:8000/healthz
```

Expected response:

```json
{"status":"healthy"}
```

#### 2. Verify prompt handling

Prompt request:

```bash
curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Summarize the purpose of llm-gateway in one sentence."}'
```

Expected response shape:

```json
{
  "answer": "..."
}
```

#### 3. Verify error handling without an API key

If you start the server without `OPENAI_API_KEY`, the health endpoint still works, but `POST /ask` should return an error:

```json
{
  "detail": "OPENAI_API_KEY is not set"
}
```

### Stop the server

Press `Ctrl+C` in the terminal running `uvicorn`.

## Container and deployment assets

- [App/Dockerfile](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/App/Dockerfile:1): container build definition
- [App/k8s/deployment.yml](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/App/k8s/deployment.yml:1): Kubernetes deployment manifest
- [App/k8s/service.yml](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/App/k8s/service.yml:1): Kubernetes service manifest
- [App/k8s/secret.example.yml](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/App/k8s/secret.example.yml:1): example secret manifest for `OPENAI_API_KEY`

## Infrastructure

Terraform configuration is split into two directories:

- [Infra/foundation](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/Infra/foundation/main.tf:1): foundational resources and shared outputs
- [Infra/platform](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/Infra/platform/main.tf:1): platform-level resources that build on the foundation layer

Each Terraform directory includes:

- `versions.tf`: provider and Terraform version constraints
- `provider.tf`: provider configuration
- `variables.tf`: input variable definitions
- `outputs.tf`: exported values
- `*.auto.tfvars.example`: example variable values

## AWS and EKS deployment flow

This repository is currently structured as a CPU-only baseline for deploying the application to Amazon EKS, with cost control focused on small Spot-backed worker nodes.

What Terraform creates:

- `Infra/foundation/`: an S3 bucket and DynamoDB table for Terraform state and locking
- `Infra/platform/`: an ECR repository and an EKS cluster with a small Spot-backed CPU managed node group

What you still do after Terraform:

- build the application image
- push the image to ECR
- create the Kubernetes secret for `OPENAI_API_KEY`
- apply the Kubernetes manifests to the EKS cluster

### Node group notes

The platform stack is configured to keep costs down by using:

- Spot capacity for the managed node group
- a small baseline size (`desired_size = 1`)
- small general-purpose instance types (`t3.small`, `t3.medium`)

Because this node group uses Spot, interruptions are expected. If you need higher availability, increase the node count or add a separate On-Demand node group.

### 1. Create foundation resources

The bootstrap stack creates:

- an S3 bucket for Terraform remote state
- versioning for state history
- server-side encryption for stored state objects
- public access blocking
- bucket ownership enforcement
- lifecycle cleanup for old noncurrent object versions
- a DynamoDB table for Terraform state locking

```bash
cd Infra/foundation
cp bootstrap.auto.tfvars.example terraform.auto.tfvars
terraform init
terraform apply
```

### 2. Configure the platform backend and create EKS

Update the S3 backend settings for `Infra/platform` to use the bucket and lock table created by the foundation stack, then run:

```bash
cd Infra/platform
cp terraform.auto.tfvars.example terraform.auto.tfvars
terraform init
terraform apply
```

Capture these outputs after apply:

- `cluster_name`
- `ecr_repository_url`

### 3. Build and push the container image

```bash
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <your-account>.dkr.ecr.us-west-2.amazonaws.com
docker build -t llm-gateway:latest App
docker tag llm-gateway:latest <ecr_repository_url>:latest
docker push <ecr_repository_url>:latest
```

Replace `<ecr_repository_url>` with the Terraform output value.

### 4. Connect `kubectl` to the cluster

```bash
aws eks update-kubeconfig --region us-west-2 --name <cluster_name>
```

### 5. Create the application secret

Create a working secret manifest from the example file:

```bash
cp App/k8s/secret.example.yml App/k8s/secret.yml
```

Set `stringData.api-key` in `App/k8s/secret.yml` to your OpenAI API key, then apply it:

```bash
kubectl apply -f App/k8s/secret.yml
```

### 6. Deploy the application

Update the image reference in [App/k8s/deployment.yml](/Users/pavanbedadham/Documents/Personnel/Tech/llm-gateway/App/k8s/deployment.yml:1) to the real ECR image URL, then apply the manifests:

```bash
kubectl apply -f App/k8s/deployment.yml
kubectl apply -f App/k8s/service.yml
```

### 7. Verify the deployment

```bash
kubectl get pods
kubectl get nodes
kubectl get svc llm-gateway
kubectl describe deployment llm-gateway
```

If the service receives an external address, you can test it with:

```bash
curl http://<external-address>/healthz
```

## Project intent

This repository is intentionally lightweight. It is meant to serve as an experimentation space for:

- exposing AI capabilities through a simple gateway service
- testing deployment patterns across application and infrastructure layers
- iterating on ideas that are worth sharing publicly as work samples or learning updates

## GitHub and LinkedIn summary

If you want a short description for external profiles, use this:

`Sandbox for experimenting with AI gateway exposure, deployment patterns, and infrastructure workflows using FastAPI, Kubernetes, and Terraform.`
