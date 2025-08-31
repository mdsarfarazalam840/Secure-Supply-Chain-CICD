# Secure-Supply-Chain-CICD
end-to-end secure CI/CD pipeline


🔐 Project 2: Secure Supply Chain CI/CD (Step-by-Step Guide)
🎯 Goal

Build → Scan → Sign → Deploy only secure Docker images.

Any unsigned / vulnerable image must be blocked by Kubernetes.

🛠️ Tech Stack

App: Simple Node.js app (hello-world).

CI/CD: GitHub Actions.

Security Tools:

Trivy → scan image vulnerabilities.

Syft → generate SBOM (list of dependencies).

Cosign → sign images.

Cluster: Kubernetes (Minikube/Docker Desktop).

Policy Engine: Kyverno/OPA Gatekeeper → enforce “signed only” policy.

📂 Folder Structure

```
secure-supply-chain/
│── app/
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
│── .github/
│   └── workflows/
│       └── ci-cd.yml
│── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── policy.yaml   # blocks unsigned images

```


🧩 Step 5: Run & Test
```
# Start Minikube
minikube start

# Apply manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/policy.yaml

# Access app
minikube service secure-app-service --url
```


✅ Success Test Cases:

Deploy signed image → works.

Deploy unsigned image → blocked by policy.

Pipeline fails if vulnerabilities found.


📘 Outcome

You built an end-to-end secure CI/CD pipeline.

You enforced only signed, vulnerability-free images in Kubernetes.

This is production-grade — and most engineers don’t go this deep → huge interview plus.
