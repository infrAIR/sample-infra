# sample-infra

Test bed for [infAIR](https://github.com/infrAIR/parser) CI/CD workflows.

Contains a realistic multi-layer AWS infrastructure in Terraform that exercises both:

- **PR blast radius reports** — automatically posts an impact analysis comment on every PR that touches `.tf` files
- **Platform view sync** — pushes the parsed infrastructure graph to Neo4j whenever changes land on `main`

## Infrastructure layout

```
Exposure     aws_lb · aws_lb_listener · aws_acm_certificate
               │
Compute      aws_ecs_service (api) · aws_ecs_service (worker) · aws_lambda_function
               │
Identity     aws_iam_role (ecs-task) · aws_iam_role (lambda)
               │
Data         aws_db_instance (primary + replica) · aws_elasticache_cluster · aws_s3_bucket · aws_sqs_queue
```

## Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `blast-report.yml` | PR touching `terraform/**` | Builds `prcheck`, generates plan, posts blast radius comment |
| `graph-sync.yml` | Push to `main` touching `terraform/**` | Builds `sync`, pushes parsed graph to Neo4j |

## Required secrets

Set these in **Settings → Secrets and variables → Actions**:

| Secret | Required for | Notes |
|---|---|---|
| `NEO4J_URI` | graph-sync, blast-report | e.g. `bolt://your-neo4j-host:7687` |
| `NEO4J_USERNAME` | graph-sync, blast-report | |
| `NEO4J_PASSWORD` | graph-sync, blast-report | |
| `ANTHROPIC_API_KEY` | blast-report | Adds a natural-language narrative to the PR comment |
| `AWS_ACCESS_KEY_ID` | blast-report (optional) | If absent, workflow uses `testdata/plan.json` |
| `AWS_SECRET_ACCESS_KEY` | blast-report (optional) | |

Without AWS credentials the blast-report workflow still runs — it uses the committed `testdata/plan.json` (an ECS service update) so you can test the full comment flow without a real AWS account.

## Try it

1. Fork or clone this repo
2. Add the Neo4j secrets (and optionally Anthropic + AWS)
3. Open a PR that changes anything in `terraform/` — you'll get a blast radius comment
4. Merge to `main` — the graph syncs to Neo4j and appears in the platform view
