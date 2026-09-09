\# The Complete Guide to This Project

\### (Written so anyone, even with zero background, can understand it)



This is the eleventh project in a portfolio series. It assumes the

basics from earlier guides (Git, GitHub, Terraform, CI/CD, Lambda,

DynamoDB, IAM) are already familiar. This one introduces AWS Step

Functions - a way to orchestrate multiple steps of a business process

as a single, coordinated workflow.



\---



\## Part 1 - Project goals



Every earlier Lambda-based project in this portfolio had either one

function doing one job, or independent functions connected loosely

through a queue. This project is different: it's a real business

process - processing an order - made of several steps that must

happen in a specific order, where a failure partway through needs to

be handled gracefully rather than left in a broken, half-completed

state. Step Functions is AWS's tool for exactly this problem.



\## Part 2 - Architecture



The workflow, start to finish:



1\. An order comes in (manually for testing, or optionally via

&#x20;  EventBridge)

2\. Validate the order - are the required fields present and valid?

3\. Check/reserve inventory - simulated for this project

4\. Process payment - simulated for this project

5\. Save the completed order to DynamoDB

6\. If every step succeeds - a Success state

7\. If any step fails (even after retrying) - a dedicated failure

&#x20;  handler, then a Failed state



\## Part 3 - Repository structure



step-functions-order-processing-project/

\- README.md - the overview (what/why, high level)

\- PROJECT\_GUIDE.md - this file, the full walkthrough

\- lambda/ - five Python files, one per workflow step

\- terraform/ - the infrastructure as code, split into focused files

&#x20; rather than one giant main.tf

\- .github/workflows/ - two pipelines: validation-only (runs on every

&#x20; push) and deployment (manual only)



\## Part 4 - AWS services used, and what each one is for



\- Step Functions - defines and runs the workflow itself (the "state

&#x20; machine")

\- Lambda - five separate functions, each responsible for exactly one

&#x20; step

\- DynamoDB - stores the final, completed order

\- IAM - two kinds of roles: one the Step Functions state machine

&#x20; itself uses (to be allowed to invoke the Lambda functions), and one

&#x20; each Lambda function uses (to be allowed to do its own specific job)

\- EventBridge (optional, disabled by default) - could trigger the

&#x20; workflow automatically from a real event instead of a manual test



\## Part 5 - What each Lambda does



\- validate\_order.py - checks that required fields are present, that

&#x20; the order has at least one item, and that the total amount is

&#x20; positive. Returns the validated order unchanged if everything looks

&#x20; right.

\- check\_inventory.py - simulates reserving inventory (no real

&#x20; inventory system involved). Returns the order plus an

&#x20; inventory\_status field.

\- process\_payment.py - simulates charging a payment, but only if

&#x20; inventory was actually reserved. Returns the order plus a

&#x20; payment\_status and a transaction\_id.

\- save\_order.py - writes the completed order to DynamoDB, but only if

&#x20; payment actually succeeded. Reads the table name from an environment

&#x20; variable rather than hardcoding it.

\- handle\_failure.py - runs only when something upstream fails. Returns

&#x20; a clear failure description. In a real system, this is also where

&#x20; you'd release any inventory that was reserved before the failure

&#x20; happened (not implemented here, since this project is educational).



None of these Lambdas process real payments or connect to a real

inventory system - everything is simulated, clearly labeled as such in

the code itself.



\## Part 6 - Step Functions concepts (new for this project)



\- \*\*Task state\*\* - a single step that actually does something, usually

&#x20; by invoking a Lambda function.

\- \*\*Succeed state\*\* - marks the workflow as finished successfully.

\- \*\*Fail state\*\* - marks the workflow as finished, but failed.

\- \*\*Retry\*\* - tells a Task state "if this specific kind of error

&#x20; happens, try again automatically before giving up," useful for

&#x20; brief, transient problems rather than real bugs.

\- \*\*Catch\*\* - tells a Task state "if this fails even after retrying,

&#x20; don't just stop - go run this other state instead" (in this project,

&#x20; the failure handler).

\- \*\*Parameters\*\* - lets you reshape or select exactly what data a

&#x20; Task actually receives, rather than passing the entire workflow

&#x20; state through unchanged.

\- \*\*ResultPath\*\* - controls where a Task's output gets placed within

&#x20; the workflow's overall data, so you can add new information without

&#x20; overwriting what came before it.



\## Part 7 - DynamoDB table design



A single table storing one item per completed order, with the order's

ID as the primary key. Only the save\_order Lambda ever writes to it,

and it only writes orders that have already passed validation,

inventory reservation, and payment - by the time anything reaches

DynamoDB, the whole process has already succeeded.



\## Part 8 - IAM roles and policies



Two distinct roles, matching the two distinct things that need

permission to act:



\- The Step Functions state machine's own role - needs permission to

&#x20; invoke each of the five Lambda functions, nothing more.

\- Each Lambda's own execution role - needs permission to write logs

&#x20; (all five), and the save\_order function specifically needs

&#x20; permission to write to the DynamoDB table (and only that one

&#x20; action, on only that one table).



\## Part 9 - GitHub repository and Actions setup



(Filled in as we actually build each piece.)



\## Part 10 - AWS credentials setup



(Filled in when we reach that phase - will cover both the OIDC

approach and the simpler long-lived access key approach, with an

honest explanation of the tradeoff.)



\## Part 11 - Validation



(Filled in once the validation-only pipeline is built.)



\## Part 12 - Deployment



(Filled in once the deployment pipeline is built.)



\## Part 13 - Testing



(Filled in once the project is deployed - will cover triggering a

successful run, an intentionally invalid order, and checking results

in DynamoDB and CloudWatch.)



\## Part 14 - Troubleshooting and common errors



(Filled in with whatever real errors we actually hit while building

this, matching the pattern from every earlier project's documentation.)



\## Part 15 - Cleanup



(Filled in once the project is deployed and we know exactly what needs

tearing down.)



\## Part 16 - Cost warnings



(Filled in with actual cost information once deployed.)



\## Part 17 - Possible improvements



\- Add real inventory-release logic to the failure handler

\- Enable the EventBridge trigger for real event-driven starts

\- Add a Wait state to simulate a slower, asynchronous payment provider



\---



\*This document will be completed with real details, real errors, and

real fixes as the project is actually built - not written in advance

of the work.\*

