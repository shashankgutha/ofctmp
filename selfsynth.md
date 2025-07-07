Overview
This document outlines the automated flow for managing Elastic Agent configurations through GitHub pull requests, validation, and deployment.

Process Flow Diagram
┌─────────────────────────────────────────────────────────────────────┐
│                    Configuration Management Flow                     │
└─────────────────────────────────────────────────────────────────────┘

Developer              GitHub                 Workflow                 System
    │                     │                      │                      │
    │ 1. Create input     │                      │                      │
    │    file in inputs/  │                      │                      │
    │                     │                      │                      │
    │ 2. Create PR        │                      │                      │
    ├────────────────────▶│                      │                      │
    │                     │                      │                      │
    │                     │ 3. PR Event         │                      │
    │                     ├─────────────────────▶│                      │
    │                     │                      │                      │
    │                     │                      │ 4. Validation        │
    │                     │                      ├─────────────────────▶│
    │                     │                      │                      │
    │                     │                      │ 5. Schema Check      │
    │                     │                      │◄─────────────────────┤
    │                     │                      │                      │
    │                     │ 6. Preview Comment   │                      │
    │                     │◄─────────────────────┤                      │
    │                     │                      │                      │
    │ 7. Review & Merge   │                      │                      │
    ├────────────────────▶│                      │                      │
    │                     │                      │                      │
    │                     │ 8. Merge Event       │                      │
    │                     ├─────────────────────▶│                      │
    │                     │                      │                      │
    │                     │                      │ 9. Backup & Merge    │
    │                     │                      ├─────────────────────▶│
    │                     │                      │                      │
    │                     │                      │ 10. Update Config    │
    │                     │                      │◄─────────────────────┤
    │                     │                      │                      │
    │                     │ 11. Commit Changes   │                      │
    │                     │◄─────────────────────┤                      │
    │                     │                      │                      │

Detailed Flow Steps
Phase 1: Configuration Submission
Step 1: Create Input File

Developer creates YAML configuration file in inputs/ directory

File contains new input configuration for Elastic Agent

Follows standard Elastic Agent input format

Step 2: Create Pull Request

Developer creates PR with input file changes

PR targets main branch with changes in inputs/ path

Automatic workflow trigger activated

Phase 2: Validation & Preview
Step 3: Workflow Trigger

GitHub Actions workflow triggered on PR events

Workflow runs with restricted permissions

Concurrent execution prevented by workflow groups

Step 4: Security Validation

Path traversal protection validates file locations
Filename validation ensures safe operations

Step 5: Configuration Validation

YAML syntax validation

Elastic Agent schema compliance check

Duplicate input ID detection


Step 6: Preview Generation

Generate merged configuration preview

Post preview comment on PR

Show validation results and changes

Phase 3: Merge & Deployment
Step 7: Code Review & Merge

Team reviews PR and preview

Approves and merges PR

Merge event triggers deployment workflow

Step 8: Secure Merge Process

File locking prevents concurrent access


Step 9: Configuration Update

New inputs merged into main elastic-agent.yml

Final validation of merged configuration

Rollback on any errors

Step 10: Commit & Deploy

Updated configuration committed to repository

