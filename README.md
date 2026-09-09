# Step Functions Order Processing Project

## What this project does

A serverless order-processing workflow built with AWS Step Functions.
Step Functions orchestrates five separate Lambda functions in sequence:

1. Validate the order
2. Check/reserve inventory
3. Process payment (simulated)
4. Save the completed order to DynamoDB
5. Handle any failure that occurs along the way

## Why Step Functions?

Every earlier project in this portfolio either had one Lambda doing
one job, or independent Lambdas connected loosely through a queue.
This project introduces a genuinely different problem: a business
process with several sequential, dependent steps, where step 2 can't
run until step 1 succeeds, and a failure partway through needs to be
handled gracefully rather than leaving things in a broken, half-done
state.

Step Functions is AWS's managed service for exactly this: defining a
"state machine" (a workflow) that calls each step in order, passes
data between them, retries on transient errors, and routes to a
dedicated failure-handling path when something goes wrong.

## Architecture

```
Manual test (or EventBridge, disabled by default)
        |
        v
AWS Step Functions state machine
        |
        +--> Validate order Lambda
        |
        +--> Check inventory Lambda
        |
        +--> Process payment Lambda
        |
        +--> Save order Lambda
        |
        +--> Success state
```

If any step fails:

```
Step Functions retry (for transient errors)
        |
        v
Failure handler Lambda
        |
        v
Failed state
```

## AWS services used

- Step Functions - orchestrates the workflow itself
- Lambda - five separate functions, one per step
- DynamoDB - stores the completed order
- IAM - separate, scoped roles for the Step Functions state machine
  and for the Lambda functions themselves, plus an OIDC-based role for
  GitHub Actions (no stored AWS keys)
- EventBridge (optional) - can trigger the workflow automatically from
  an event, disabled by default

## How data moves between states

Step Functions passes a JSON object from one state to the next. Each
Lambda receives the current JSON (shaped by that state's `Parameters`
block), does its job, and returns an updated JSON that gets placed
back into the workflow's data at the path specified by `ResultPath`.
Every main step in this project uses `"order.$": "$.order"` as its
input and `"ResultPath": "$.order"` for its output, so each step reads
and overwrites the same `order` object, carrying forward everything
every previous step added to it.

## How failures and retries work

Each main step has:
- A **Retry** rule for transient errors (`Lambda.ServiceException`,
  `Lambda.TooManyRequestsException`) - tries again automatically
  (up to 2 times, with backoff) before giving up
- A **Catch** rule using `States.ALL` - if a step fails even after
  retrying, the workflow routes to `HandleFailure` instead of just
  stopping, which produces a clean, structured failure report

## How Terraform is used

All infrastructure - the DynamoDB table, the five Lambda functions,
both IAM roles, the OIDC trust setup, and the Step Functions state
machine itself - is defined as Terraform code, split across focused
files (`dynamodb.tf`, `iam.tf`, `lambda.tf`, `step_functions.tf`)
rather than one giant file. Terraform is never installed locally; it
only ever runs inside GitHub Actions.

## How GitHub Actions is used

Two separate workflows:
- **Validation** (`terraform-validation.yml`, runs on every push/PR):
  checks formatting and syntax only, using `terraform init -backend=false`
  - never touches real AWS resources and needs no AWS credentials at all.
- **Deployment** (`deploy.yml`, manual only via `workflow_dispatch`):
  requires typing the word "deploy" into a confirmation input, runs
  `terraform plan` first, then `apply` behind a protected GitHub
  Environment requiring manual approval - two independent layers of
  intentional friction before anything real happens.

Deployment authenticates to AWS using **OIDC** (OpenID Connect) rather
than long-lived access keys - GitHub generates a short-lived,
cryptographically verified token at runtime instead of a stored
secret. See PROJECT_GUIDE.md for the full setup and a real bug hit
while configuring it.

## Cost considerations

Genuinely low cost. Every service used bills per-use with generous
free tiers:
- **Step Functions**: Standard workflows bill per state transition
  (roughly $0.025 per 1,000 transitions) - each test execution used
  5-13 transitions, effectively free at portfolio-demo volume.
- **Lambda**: pay per invocation and duration - each function runs for
  well under a second.
- **DynamoDB**: `PAY_PER_REQUEST` mode - pennies for the handful of
  items written during testing.
- **No idle server cost anywhere** in this architecture.

Total cost for building, testing, and documenting this entire project
was effectively negligible - well under $0.10.

## How to clean up AWS resources

Since costs are negligible, this project can safely be left deployed.
If you want to tear it down completely:

1. Run `terraform destroy` via a manual GitHub Actions workflow (not
   included by default in this project, but easy to add following the
   same pattern as `deploy.yml`, swapping `terraform apply` for
   `terraform destroy -auto-approve`).
2. Manually delete the DynamoDB table's contents first if `destroy`
   ever complains about it not being empty (DynamoDB tables in
   `PAY_PER_REQUEST` mode delete cleanly regardless of contents, so
   this is unlikely to actually be needed here).

## What you'll learn

- AWS Step Functions state machines and the Amazon States Language
- Task, Succeed, Fail, Retry, Catch, and Parameters states
- Passing JSON data between workflow steps via `ResultPath`
- Lambda integration with Step Functions
- DynamoDB persistence, including a real `Decimal` vs `float` gotcha
- IAM roles and least-privilege permissions across a multi-service
  workflow
- Setting up GitHub Actions OIDC authentication to AWS from scratch,
  including a genuinely difficult real bug and how to diagnose it
  using CloudTrail

## Problems & fixes - quick reference

| Problem | Why it happened | How it was fixed |
|---|---|---|
| OIDC role assumption failed repeatedly (`Not authorized to perform sts:AssumeRoleWithWebIdentity`) | The trust policy's `sub` condition was written for the classic `repo:owner/repo:*` format, but GitHub's actual token included numeric "immutable IDs" (`repo:Ralso11@245895333/step-functions-order-processing-project@1361544691:...`) | Diagnosed via CloudTrail Event history (filtering by `AssumeRoleWithWebIdentity`), which showed the real token content; updated the trust policy's `sub` condition to `repo:Ralso11@*/step-functions-order-processing-project@*:*` |
| A stray space in an early trust policy attempt (`Ralso11/ step-functions...`) | Manual typo while editing the JSON in the AWS Console | Retyped cleanly |
| DynamoDB write failed: `Float types are not supported. Use Decimal types instead.` | `total_amount` was a plain Python `float` (`29.99`); DynamoDB's Python library requires `Decimal` for numeric precision | Converted with `Decimal(str(order["total_amount"]))` before writing, in `save_order.py` |

Both the success path and the failure path were tested for real and
verified: a valid order correctly persisted to DynamoDB with every
field intact, and an invalid order was correctly caught, routed to the
failure handler, and ended in a graceful `Failed` state rather than
crashing.
