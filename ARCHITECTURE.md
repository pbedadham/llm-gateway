# Architecture

## System overview

The current design is a lightweight CPU-only gateway. The service does not run model inference inside the cluster. Instead, it accepts API requests, forwards prompts to OpenAI, and returns the response.

```mermaid
flowchart TD
    U[Client / Consumer] --> LB[AWS LoadBalancer Service]
    LB --> POD[llm-gateway Pod<br/>FastAPI]
    POD --> SEC[Kubernetes Secret<br/>llm-secrets]
    POD --> OAI[OpenAI Responses API]

    subgraph EKS[AWS EKS Cluster]
        subgraph NG[Managed Node Group<br/>Spot CPU nodes]
            POD
        end
        LB
        SEC
    end

    subgraph AWS[AWS Infrastructure]
        EKS
        ECR[Amazon ECR<br/>llm-gateway image]
        S3[S3 Bucket<br/>Terraform state]
        DDB[DynamoDB Table<br/>Terraform lock]
    end

    GH[GitHub Actions] --> ECR
    GH --> EKS
    GH --> S3
    GH --> DDB
```

## Deployment flow

```mermaid
flowchart LR
    FB[Foundation Bootstrap] --> TFSTATE[S3 state bucket + DynamoDB lock table]
    TFSTATE --> DEPLOY[Deploy workflow]
    DEPLOY --> PLATFORM[Terraform apply<br/>Infra/platform]
    PLATFORM --> EKS[EKS cluster + ECR repository]
    DEPLOY --> BUILD[Build and push app image]
    BUILD --> ECR[Amazon ECR]
    DEPLOY --> K8S[Apply Kubernetes manifests]
    K8S --> APP[llm-gateway Deployment + Service]
```

## Workflow sequence

```mermaid
sequenceDiagram
    participant User
    participant GH as GitHub Actions
    participant F as Foundation Bootstrap
    participant S3 as S3 State Bucket
    participant DDB as DynamoDB Lock Table
    participant D as Deploy
    participant TF as Terraform Platform
    participant EKS as Amazon EKS
    participant ECR as Amazon ECR

    User->>GH: Run Foundation Bootstrap
    GH->>F: Execute foundation workflow
    F->>S3: Create / manage Terraform state bucket
    F->>DDB: Create / manage lock table

    User->>GH: Run Deploy
    GH->>D: Execute deploy workflow
    D->>TF: terraform apply Infra/platform
    TF->>EKS: Create / update cluster
    TF->>ECR: Create / update repository
    D->>ECR: Build and push llm-gateway image
    D->>EKS: Apply secret, deployment, and service
```

## Simplified request flow

```mermaid
flowchart LR
    Client --> Service[llm-gateway Service]
    Service --> Pod[FastAPI Pod]
    Pod --> OpenAI[OpenAI API]
```

## Responsibility split

- `Infra/foundation`: backend state infrastructure for Terraform
- `Infra/platform`: EKS cluster and ECR repository
- `App/`: FastAPI gateway, Docker image, and Kubernetes manifests
- `.github/workflows/`: CI, bootstrap, deploy, and destroy automation

## Current runtime model

- The application runs on small CPU nodes in EKS
- Kubernetes stores `OPENAI_API_KEY` in `llm-secrets`
- The gateway calls OpenAI over HTTPS
- No local GPU inference is part of the current architecture
