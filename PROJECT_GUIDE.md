# The Complete Guide to This Project
### (Written so anyone, even with zero background, can understand it)

This is the eleventh project in a portfolio series. It assumes the
basics from earlier guides (Git, GitHub, Terraform, CI/CD, Lambda,
DynamoDB, IAM) are already familiar. This one introduces AWS Step
Functions - a way to orchestrate multiple steps of a business process
as a single, coordinated workflow - and GitHub Actions OIDC
authentication, used here for the first time in this portfolio.

---

## Part 1 - Project goals

Every earlier Lambda-based project in this portfolio had either one
function doing one job, or independent functions connected loosely
through a queue. This project is different: it's a real business
process - processing an order - made of several steps that must
happen in a specific order, where a failure partway through needs to
be handled gracefully rather than left in a broken, half-completed
state. Step Functions is AWS's tool for exactly this problem.

## Part 2 - Architecture

The workflow, start to finish:

1. An order comes in (manually for testing, or optionally via
   EventBridge, disabled by default)
2. Validate the order - are the required fields present and valid?
3. Check/reserve inventory - simulated for this project
4. Process payment - simulated for this project
5. Save the completed order to DynamoDB
6. If every step succeeds - a Success state
7. If any step fails (even after retrying) - a dedicated failure
   handler, then a Failed state

## Part 3 - Repository structure

```
step-functions-order-processing-project/
├── README.md
├── PROJECT_GUIDE.md
├── lambda/
│   ├── validate_order.py
│   ├── check_inventory.py
│   ├── process_payment.py
│   ├── save_order.py
│   └── handle_failure.py
├── terraform/
│   ├── versions.tf
│   ├── variables.tf
│   ├── dynamodb.tf
│   ├── iam.tf
│   ├── lambda.tf
│   ├── step_functions.tf
│   ├── order_workflow.asl.json
│   ├── outputs.tf
│   └── backend.tf
└── .github/workflows/
    ├── terraform-validation.yml
    └── deploy.yml
```

## Part 4 - AWS services used, and what each one is for

- Step Functions - defines and runs the workflow itself (the "state
  machine")
- Lambda - five separate functions, each responsible for exactly one
  step
- DynamoDB - stores the final, completed order
- IAM - three distinct roles: one the Step Functions state machine
  itself uses, one all five Lambda functions share, and one GitHub
  Actions assumes via OIDC to deploy everything
- EventBridge (optional, disabled by default) - could trigger the
  workflow automatically from a real event instead of a manual test

## Part 5 - What each Lambda does

- **validate_order.py** - checks that required fields are present,
  that the order has at least one item, and that the total amount is
  positive. Returns the validated order unchanged if everything looks
  right; raises `ValueError` otherwise (which is how a workflow step
  "fails" in Step Functions terms).
- **check_inventory.py** - simulates reserving inventory. Returns the
  order plus an `inventory_status` field.
- **process_payment.py** - simulates charging a payment, only if
  inventory was actually reserved first. Returns the order plus
  `payment_status` and a `transaction_id`.
- **save_order.py** - writes the completed order to DynamoDB, only if
  payment actually succeeded. Reads the table name from an environment
  variable. Converts `total_amount` to `Decimal` before writing (see
  Part 13 for why this was a real bug).
- **handle_failure.py** - runs only when something upstream fails.
  Returns a clear, structured failure description. In a real system,
  this is also where you'd release any inventory reserved before the
  failure - not implemented here, since this project is educational.

None of these Lambdas process real payments or connect to a real
inventory system - everything is simulated, clearly labeled as such.

## Part 6 - Step Functions concepts

- **Task state** - a single step that actually does something, here
  by invoking a Lambda function.
- **Succeed state** - marks the workflow as finished successfully.
- **Fail state** - marks the workflow as finished, but failed.
- **Retry** - "if this specific kind of error happens, try again
  automatically before giving up" - useful for brief, transient
  problems, not real bugs.
- **Catch** - "if this fails even after retrying, don't just stop -
  go run this other state instead."
- **Parameters** - reshapes or selects exactly what data a Task
  actually receives.
- **ResultPath** - controls where a Task's output gets placed within
  the workflow's overall data.

### How the JSON paths actually work in this project

Every main Task uses this pattern:
```json
"Parameters": { "order.$": "$.order" },
"ResultPath": "$.order"
```
The `.$` suffix means "this value comes from a JSON path, not a
literal string" - so `"order.$": "$.order"` means "take whatever is
currently at `$.order` and pass it as the `order` field." Since
`ResultPath` is also `$.order`, each step's return value overwrites
that same location - meaning every step sees everything every
previous step added, and adds its own piece on top.

`HandleFailure` is different - it reads both `$.order` (whatever
existed when the failure happened) and `$.error` (details Step
Functions automatically populated via the `Catch` rule's own
`ResultPath`), and writes its own result to `$.failureResult` instead
of overwriting `$.order` - since at that point, the order didn't
actually complete successfully.

## Part 7 - DynamoDB table design

A single table, one item per completed order, `order_id` as the
primary key (type `S`, String). Only `save_order` ever writes to it,
and only once payment has already succeeded - by the time anything
reaches DynamoDB, the whole preceding process has already worked.

## Part 8 - IAM roles and policies

Three distinct roles for three distinct things that need permission:

- **The Lambda execution role** (shared by all five functions) - can
  write CloudWatch logs (all five), and only `PutItem` on the orders
  table specifically (needed by `save_order`, harmless for the other
  four to technically have but never use).
- **The Step Functions role** - can only `lambda:InvokeFunction` on
  exactly these five specific Lambda ARNs, nothing else.
- **The GitHub Actions OIDC role** - can manage this project's Lambda
  functions and IAM roles (scoped by name prefix), plus broader
  DynamoDB and Step Functions access (contained services, same
  reasoning as earlier projects' "managed policy for a naturally
  contained service" pattern), and read/write access to just this
  project's slice of the shared Terraform state bucket.

## Part 9 - GitHub repository setup

Created via github.com/new, public, with an auto-generated README,
then cloned locally with `git clone` - the same pattern as every
other project in this portfolio.

## Part 10 - GitHub Actions setup

Two workflow files in `.github/workflows/`:
- `terraform-validation.yml` - triggers on every push and pull
  request, runs entirely without AWS credentials.
- `deploy.yml` - triggers only via `workflow_dispatch`, with a
  required text input (`confirm`) that must exactly equal `"deploy"`
  for the `apply` job to run at all, on top of the GitHub Environment
  approval gate.

## Part 11 - AWS credentials setup: OIDC, and a real bug

This project uses **OIDC (OpenID Connect)** instead of long-lived AWS
access keys - the first time in this portfolio. Setup involved three
pieces:

1. **An IAM Identity Provider** for `token.actions.githubusercontent.com`
   - a one-time, account-wide trust relationship with GitHub's token
   issuer.
2. **An IAM role** (`step-functions-github-actions-role`) with a trust
   policy restricting *which* GitHub repository is allowed to assume
   it.
3. **A workflow permission** (`permissions: id-token: write`) enabling
   the specific GitHub Actions job to request a token in the first
   place.

### The real bug, and how it was actually diagnosed

The role assumption failed repeatedly with
`Not authorized to perform sts:AssumeRoleWithWebIdentity`, even after
fixing an initial typo (a stray space in the trust policy) and
verifying every visible piece of configuration matched. A broad
diagnostic test (temporarily setting the trust condition to match *any*
repo under the account) still failed identically - proving the problem
wasn't about the specific repo name string at all.

**The actual root cause was found by checking AWS CloudTrail's Event
history**, filtered to the `AssumeRoleWithWebIdentity` event, which
showed the *real* token GitHub had sent:
```
repo:Ralso11@245895333/step-functions-order-processing-project@1361544691:ref:refs/heads/main
```
GitHub had included numeric **immutable IDs** (`@245895333`,
`@1361544691`) - a newer security feature that prevents someone from
renaming or deleting/recreating a repository to impersonate an older
one. The classic `repo:owner/repo:*` trust-policy pattern (still the
most commonly documented format online) simply doesn't account for
this newer format at all.

**The fix:**
```json
"token.actions.githubusercontent.com:sub": "repo:Ralso11@*/step-functions-order-processing-project@*:*"
```

**The real lesson:** when something fails with a generic
"not authorized" message and every visible piece of configuration
looks correct, the fastest real path forward is checking the
*authoritative* source of truth - here, CloudTrail's actual logged
event - rather than continuing to guess at the visible configuration.
This is a genuinely valuable, transferable debugging instinct: prefer
verifying the real data over re-checking assumptions.

### On the OIDC vs. access-keys tradeoff

Every other project in this portfolio uses long-lived IAM user access
keys stored as GitHub Secrets - simpler to set up, but a leaked key
works indefinitely until manually revoked. OIDC has more one-time
setup complexity (as this project's bug demonstrates), but nothing
permanent is ever stored - GitHub requests a short-lived token at
runtime, AWS verifies it cryptographically against the trust policy,
and grants temporary access that expires automatically. OIDC is AWS's
current recommended best practice for GitHub Actions specifically for
this reason.

## Part 12 - Validation

`terraform-validation.yml` runs `terraform fmt -check`,
`terraform init -backend=false`, and `terraform validate` on every
push. `-backend=false` is the key detail - it skips connecting to the
real S3 state backend entirely, meaning this workflow needs zero AWS
credentials and can never touch real infrastructure, no matter what.
It passed cleanly on the first attempt for this project.

## Part 13 - Deployment, and a real DynamoDB bug

`deploy.yml` requires manually triggering with the `confirm` input set
to `"deploy"`, runs `plan`, then `apply` behind a required-approval
GitHub Environment.

The first real deployment succeeded cleanly (after resolving the OIDC
trust policy bug above). However, the first **test execution** of the
actual workflow failed at the `SaveOrder` step with:
```
Float types are not supported. Use Decimal types instead.
```
**Why:** `total_amount` was a plain Python `float` (`29.99`), but
DynamoDB's Python library (`boto3`) refuses to write native floats
directly - floats can carry tiny binary rounding imprecision, which
matters for something like a monetary amount. DynamoDB requires
Python's `Decimal` type instead, which represents numbers exactly.

**The fix**, in `save_order.py`:
```python
from decimal import Decimal
order["total_amount"] = Decimal(str(order["total_amount"]))
```
Converting through a string first (`str(...)`) matters - converting a
`float` directly to `Decimal` can actually preserve the float's
existing imprecision rather than fixing it; going through the string
representation avoids that.

## Part 14 - Testing

Both paths of the workflow were tested for real, not just deployed and
assumed to work:

**Success path:** a valid order (`order-001`, `total_amount: 29.99`)
was submitted via Step Functions' "Start execution." The full
graph view showed every state - `ValidateOrder`, `CheckInventory`,
`ProcessPayment`, `SaveOrder`, `OrderSucceeded` - turning green in
sequence, completing in about 2 seconds. Checking DynamoDB directly
afterward confirmed the item was genuinely saved, with every field
correctly present: `inventory_status: RESERVED`,
`payment_status: PAID`, `total_amount: 29.99` (correctly stored as a
Decimal), `transaction_id: demo-order-001`.

**Failure path:** an intentionally invalid order (missing
`total_amount` entirely) was submitted the same way. `ValidateOrder`
correctly failed with `ValueError: Missing required field:
total_amount`; the `Catch` rule caught it and routed to
`HandleFailure`, which ran successfully and produced a clean
`failureResult`; the execution correctly ended in the `OrderFailed`
state with `Execution status: Failed` - a graceful, informative
failure rather than a crash.

## Part 15 - Troubleshooting and common errors actually encountered

| Symptom | Cause | Fix |
|---|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy `sub` condition didn't account for GitHub's immutable-ID token format | Checked CloudTrail's actual logged event; updated the condition to `repo:Ralso11@*/step-functions-order-processing-project@*:*` |
| Same error, briefly, after an edit | A stray space typo in a manually-edited trust policy JSON | Retyped the JSON cleanly |
| `Float types are not supported. Use Decimal types instead.` | DynamoDB's Python library rejects native `float` values | Converted to `Decimal(str(value))` before writing |

## Part 16 - Cleanup

Costs are negligible enough that this project can reasonably stay
deployed. To fully tear it down, a `terraform destroy` workflow
following the same pattern as `deploy.yml` (swapping `apply` for
`destroy -auto-approve`) would remove everything cleanly, since every
resource here is either pay-per-use with no idle cost, or (for
DynamoDB in `PAY_PER_REQUEST` mode) deletes without needing to be
emptied first.

## Part 17 - Cost warnings

All actual testing and deployment for this project cost well under
$0.10 total - Step Functions bills per state transition
(~$0.025/1,000), Lambda per invocation/duration, and DynamoDB
per-request in `PAY_PER_REQUEST` mode. No component of this
architecture has any idle, always-on cost.

## Part 18 - Possible improvements

- Add real inventory-release logic to the failure handler
- Enable the EventBridge trigger for real event-driven starts
- Add a Wait state to simulate a slower, asynchronous payment provider
- Add a `terraform destroy` workflow for one-click teardown, matching
  the pattern used in several earlier portfolio projects

## Part 19 - How to explain this project in an interview

> "I built a serverless order-processing workflow using AWS Step
> Functions to orchestrate five Lambda functions - validating an
> order, reserving inventory, processing payment, and saving the
> result to DynamoDB, with proper retry and failure-handling logic
> throughout. I set up GitHub Actions deployment using OIDC instead of
> stored AWS credentials, which took real troubleshooting - the trust
> policy kept failing until I checked AWS CloudTrail directly and
> discovered GitHub was sending a newer token format with numeric
> repository IDs that the standard documented trust-policy pattern
> doesn't account for. I also hit a real DynamoDB bug where it
> rejected a plain Python float for a monetary field, which I fixed by
> converting to Decimal. I tested both the success and failure paths
> of the workflow for real, not just deployed and assumed - confirming
> a valid order persists correctly and an invalid one fails gracefully
> through the Catch/HandleFailure logic rather than crashing."

That story demonstrates orchestration design, real security-conscious
credential handling, and a genuine debugging instinct - checking
authoritative logs rather than re-guessing visible configuration -
which is exactly the kind of judgment that comes up in real
production incidents.

---

*This document reflects the project exactly as it was actually built,
including every real error hit along the way and how each was
diagnosed and fixed.*
