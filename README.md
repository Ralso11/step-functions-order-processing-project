\# Step Functions Order Processing Project



\## What this project does



A serverless order-processing workflow built with AWS Step Functions.

Step Functions orchestrates five separate Lambda functions in sequence:



1\. Validate the order

2\. Check/reserve inventory

3\. Process payment (simulated)

4\. Save the completed order to DynamoDB

5\. Handle any failure that occurs along the way



\## Why Step Functions?



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



\## Architecture



EventBridge or manual test

&#x20;       |

&#x20;       v

AWS Step Functions state machine

&#x20;       |

&#x20;       +--> Validate order Lambda

&#x20;       |

&#x20;       +--> Check inventory Lambda

&#x20;       |

&#x20;       +--> Process payment Lambda

&#x20;       |

&#x20;       +--> Save order Lambda

&#x20;       |

&#x20;       +--> Success state



If any step fails:



Step Functions retry (for transient errors)

&#x20;       |

&#x20;       v

Failure handler Lambda

&#x20;       |

&#x20;       v

Failed state



\## AWS services used



\- Step Functions - orchestrates the workflow itself

\- Lambda - five separate functions, one per step

\- DynamoDB - stores the completed order

\- IAM - separate, scoped roles for the Step Functions state machine

&#x20; and for the Lambda functions themselves

\- EventBridge (optional) - can trigger the workflow automatically

&#x20; from an event, disabled by default



\## How data moves between states



Step Functions passes a JSON object from one state to the next. Each

Lambda receives the current JSON, does its job, and returns an updated

JSON that gets merged into the workflow's data before the next step

runs. This project is careful to keep the Step Functions JSON paths

and each Lambda's expected input/output shapes consistent with each

other - a common source of real bugs, covered in PROJECT\_GUIDE.md.



\## How failures and retries work



Each main step has:

\- A Retry rule for transient errors (like a brief Lambda service

&#x20; hiccup) - the step tries again automatically before giving up

\- A Catch rule using States.ALL - if a step fails even after

&#x20; retrying, the workflow routes to a dedicated failure-handling Lambda

&#x20; instead of just stopping



\## How Terraform is used



All infrastructure - the DynamoDB table, the five Lambda functions,

both IAM roles, and the Step Functions state machine itself - is

defined as Terraform code. Terraform is never installed locally for

this project; it only ever runs inside GitHub Actions.



\## How GitHub Actions is used



Two separate workflows:

\- Validation (runs on every push/PR): checks formatting and syntax

&#x20; only - never touches real AWS resources.

\- Deployment (manual only, via workflow\_dispatch): runs

&#x20; terraform plan first, requires explicit approval, then applies.



\## Cost considerations



(To be filled in once the project is built and actual costs are

confirmed.)



\## How to clean up AWS resources



(To be filled in once the project is built.)



\## What you'll learn



\- AWS Step Functions state machines and the Amazon States Language

\- Task, Succeed, Fail, Retry, Catch, and Parameters states

\- Passing JSON data between workflow steps

\- Lambda integration with Step Functions

\- Event-driven workflow design

\- DynamoDB persistence

\- IAM roles and least-privilege permissions applied across a

&#x20; multi-service workflow

