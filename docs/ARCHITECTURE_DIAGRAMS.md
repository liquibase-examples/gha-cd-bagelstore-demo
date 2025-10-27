# Architecture Diagrams

Customer-ready visualizations of the coordinated database and application deployment pattern.

## Overview

This document contains 4 different visualization approaches for presenting the architecture to customers. Each diagram emphasizes:

- **Coordinated Deployment Pattern**: Database changes deployed and validated before application updates
- **Policy-Driven Quality Gates**: 12 Liquibase policy checks enforce standards before deployment
- **Multi-Environment Progression**: Automated promotion through dev → test → staging → prod
- **AWS Infrastructure**: Production-grade deployment using RDS and App Runner

---

## 1. CI/CD Pipeline Flow (Mermaid Flowchart)

**Best for:** Showing the complete journey from code commit to production deployment.

**Use when:** You want to explain the end-to-end automation workflow.

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#1168bd','primaryTextColor':'#fff','primaryBorderColor':'#0d4f8b','lineColor':'#0d4f8b','secondaryColor':'#48bb78','tertiaryColor':'#f6ad55'}}}%%

flowchart TB
    Start([Developer Pushes Code]) --> GHA[GitHub Actions CI]

    subgraph CI["Continuous Integration"]
        GHA --> Val[Policy Validation<br/>12 Liquibase Checks]
        GHA --> Test[Integration Testing<br/>15 Test Cases]
        GHA --> Build[Build & Package]

        Val --> CheckPass{All Checks<br/>Pass?}
        CheckPass -->|No| Fail([Build Failed])
        CheckPass -->|Yes| Artifact[Create Changelog Artifact]

        Build --> Image[Push Docker Image<br/>AWS Public ECR]

        Artifact --> Trigger[Trigger Harness Webhook]
    end

    Trigger --> Harness[Harness CD Pipeline]

    subgraph CD["Continuous Deployment - Per Environment"]
        Harness --> Fetch[Fetch Changelog Artifact]

        Fetch --> DB[Update Database<br/>Liquibase + AWS RDS]
        DB --> DBSuccess{Database<br/>Updated?}
        DBSuccess -->|No| RollbackDB([Rollback])

        DBSuccess -->|Yes| App[Deploy Application<br/>AWS App Runner]
        App --> AppSuccess{Deployment<br/>Success?}
        AppSuccess -->|No| RollbackApp([Rollback])

        AppSuccess -->|Yes| Health[Health Check<br/>API Validation]
        Health --> HealthOK{Healthy?}
        HealthOK -->|No| RollbackHealth([Rollback])

        HealthOK -->|Yes| Report[Report Instances<br/>to Harness]
    end

    Report --> NextEnv{More<br/>Environments?}
    NextEnv -->|Yes| Harness
    NextEnv -->|No| Success([Deployed to Production])

    style CI fill:#e6f3ff
    style CD fill:#e6ffe6
    style Start fill:#48bb78,stroke:#2f855a,color:#fff
    style Success fill:#48bb78,stroke:#2f855a,color:#fff
    style Fail fill:#fc8181,stroke:#c53030,color:#fff
    style RollbackDB fill:#fc8181,stroke:#c53030,color:#fff
    style RollbackApp fill:#fc8181,stroke:#c53030,color:#fff
    style RollbackHealth fill:#fc8181,stroke:#c53030,color:#fff
```

**Key Message:** Database changes are validated with policy checks, then deployed before the application - ensuring schema compatibility.

---

## 2. Deployment Orchestration (Mermaid Sequence Diagram)

**Best for:** Showing the time-based coordination between systems during deployment.

**Use when:** You want to emphasize the sequential orchestration and system interactions.

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'actorBkg':'#1168bd','actorBorder':'#0d4f8b','actorTextColor':'#fff','signalColor':'#0d4f8b','signalTextColor':'#000','labelBoxBkgColor':'#e6f3ff','labelBoxBorderColor':'#1168bd'}}}%%

sequenceDiagram
    autonumber

    participant Dev as Developer
    participant GH as GitHub Actions
    participant Artifact as GitHub Artifacts
    participant Harness as Harness CD
    participant LB as Liquibase
    participant RDS as AWS RDS<br/>(PostgreSQL)
    participant ECR as AWS Public ECR
    participant AppRunner as AWS App Runner

    Dev->>GH: Push code to main branch

    rect rgb(230, 243, 255)
        Note over GH: CI Phase - Validation & Artifact Creation
        GH->>GH: Run 12 Liquibase Policy Checks
        GH->>GH: Execute 15 Integration Tests
        GH->>ECR: Build & push Docker image
        GH->>Artifact: Upload validated changelog artifact
        GH->>Harness: Trigger webhook
    end

    loop For each environment (dev, test, staging, prod)
        rect rgb(230, 255, 230)
            Note over Harness,AppRunner: CD Phase - Coordinated Deployment

            Harness->>Artifact: Fetch changelog artifact
            Artifact-->>Harness: Return changelog package

            Note over Harness,RDS: Database Update (First)
            Harness->>LB: Execute Liquibase update
            LB->>RDS: Apply changesets
            RDS-->>LB: Schema updated
            LB-->>Harness: Database deployment complete

            Note over Harness,AppRunner: Application Deployment (Second)
            Harness->>ECR: Get latest image
            ECR-->>Harness: Return image reference
            Harness->>AppRunner: Deploy new version
            AppRunner->>RDS: Connect to updated schema
            AppRunner-->>Harness: Application running

            Note over Harness,AppRunner: Validation
            Harness->>AppRunner: Health check (GET /health)
            AppRunner-->>Harness: 200 OK - Healthy
            Harness->>Harness: Report deployment success
        end
    end

    Harness-->>Dev: Deployment complete notification
```

**Key Message:** The sequence shows the critical coordination - database schema is updated BEFORE the application is deployed, ensuring compatibility.

---

## 3. System Context (Mermaid C4 Diagram)

**Best for:** Showing system boundaries and how external systems interact.

**Use when:** You want to show the big picture of system components and their relationships.

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#1168bd','primaryTextColor':'#fff','primaryBorderColor':'#0d4f8b'}}}%%

C4Context
    title System Context - Coordinated DB & App Deployment

    Person(developer, "Developer", "Writes code and database changesets")

    System_Boundary(deployment, "Deployment Automation") {
        System(github, "GitHub Actions", "CI: Validates changesets,<br/>runs policy checks,<br/>creates artifacts")
        System(harness, "Harness CD", "CD: Orchestrates deployment<br/>across 4 environments")
    }

    System_Boundary(validation, "Policy & Quality") {
        System(liquibase, "Liquibase Secure", "12 policy checks,<br/>database migrations,<br/>changelog management")
    }

    System_Boundary(aws, "AWS Infrastructure") {
        SystemDb(rds, "RDS PostgreSQL", "4 databases<br/>(dev, test, staging, prod)")
        System(apprunner, "App Runner", "4 application environments")
        System(ecr, "Public ECR", "Docker image registry")
        System(secrets, "Secrets Manager", "Database credentials,<br/>API keys")
    }

    Rel(developer, github, "Pushes code", "git push")
    Rel(github, liquibase, "Validates changesets", "Flow files + policy checks")
    Rel(github, ecr, "Publishes images", "Docker push")
    Rel(github, harness, "Triggers deployment", "Webhook")

    Rel(harness, liquibase, "Executes migrations", "Docker container")
    Rel(liquibase, rds, "Updates schema", "JDBC")

    Rel(harness, apprunner, "Deploys application", "AWS API")
    Rel(apprunner, ecr, "Pulls images", "Docker pull")
    Rel(apprunner, rds, "Connects to database", "PostgreSQL")
    Rel(apprunner, secrets, "Retrieves credentials", "AWS API")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

**Key Message:** The system demonstrates coordinated deployment by orchestrating database schema updates (Liquibase → RDS) before application deployment (App Runner).

---

## 4. Modern Alternative (D2 Diagram)

**Best for:** Modern aesthetics with automatic layout optimization.

**Use when:** You want a more contemporary look with better visual hierarchy.

**D2 Source Code:**

```d2
# Coordinated Database & Application Deployment Architecture

direction: right

developer: Developer {
  shape: person
  style.fill: "#48bb78"
}

ci: GitHub Actions CI {
  validate: Policy Validation {
    icon: https://icons.terrastruct.com/essentials/112-shield-checkmark.svg
    style.fill: "#e6f3ff"
  }
  test: Integration Testing {
    icon: https://icons.terrastruct.com/essentials/321-test-tube.svg
    style.fill: "#e6f3ff"
  }
  artifact: Create Artifact {
    icon: https://icons.terrastruct.com/essentials/087-archive.svg
    style.fill: "#e6f3ff"
  }

  validate -> test -> artifact
}

harness: Harness CD Pipeline {
  style.fill: "#fff3e6"

  stages: "4 Environments" {
    dev: Dev
    test: Test
    staging: Staging
    prod: Prod

    dev -> test -> staging -> prod
  }

  steps: "Deployment Steps (per env)" {
    fetch: Fetch Changelog
    db: Update Database {
      icon: https://icons.terrastruct.com/aws/Database/Amazon-RDS.svg
      style.fill: "#527FFF"
    }
    app: Deploy Application {
      icon: https://icons.terrastruct.com/aws/Compute/AWS-App-Runner.svg
      style.fill: "#FF9900"
    }
    health: Health Check

    fetch -> db -> app -> health
  }
}

aws: AWS Infrastructure {
  rds: RDS PostgreSQL {
    shape: cylinder
    icon: https://icons.terrastruct.com/aws/Database/Amazon-RDS.svg
    style.fill: "#527FFF"
  }

  apprunner: App Runner {
    icon: https://icons.terrastruct.com/aws/Compute/AWS-App-Runner.svg
    style.fill: "#FF9900"
  }

  secrets: Secrets Manager {
    icon: https://icons.terrastruct.com/aws/Security-Identity-Compliance/AWS-Secrets-Manager.svg
    style.fill: "#DD344C"
  }
}

liquibase: Liquibase Secure {
  checks: "12 Policy Checks" {
    style.fill: "#e6ffe6"
  }
  style.fill: "#2962FF"
}

# Relationships
developer -> ci: "git push"
ci -> harness: "trigger webhook" {
  style.stroke-dash: 3
}

harness.steps.db -> liquibase: "execute migration"
liquibase -> aws.rds: "apply changesets"

harness.steps.app -> aws.apprunner: "deploy new version"
aws.apprunner -> aws.rds: "connect to updated schema"
aws.apprunner -> aws.secrets: "retrieve credentials"

# Key Message
note: "Database schema updated FIRST,\nthen application deployed -\nensuring compatibility" {
  near: harness.steps
  style.fill: "#fff9e6"
  style.stroke: "#f6ad55"
  style.font-size: 16
}
```

**Rendering Instructions:**
```bash
# Install D2
brew install d2  # macOS
# or download from https://d2lang.com

# Render to SVG
d2 architecture.d2 architecture.svg

# Render to PNG
d2 architecture.d2 architecture.png

# With specific theme
d2 --theme=200 architecture.d2 output.svg
```

**Key Message:** Modern, clean visualization with automatic layout and icon support.

---

## Rendering & Export Instructions

### Mermaid Diagrams

**Option 1: GitHub/GitLab (Native Rendering)**
- Paste Mermaid code directly in markdown files
- Renders automatically in GitHub/GitLab UI

**Option 2: Mermaid Live Editor**
1. Visit https://mermaid.live
2. Paste diagram code
3. Export as SVG or PNG
4. Download for presentations

**Option 3: Command Line (mermaid-cli)**
```bash
# Install
npm install -g @mermaid-js/mermaid-cli

# Render to PNG
mmdc -i diagram.mmd -o diagram.png -b transparent

# Render to SVG
mmdc -i diagram.mmd -o diagram.svg

# High resolution for presentations
mmdc -i diagram.mmd -o diagram.png -w 2400 -H 1600
```

**Option 4: VS Code Extension**
1. Install "Markdown Preview Mermaid Support" extension
2. Open markdown file with mermaid diagram
3. Preview renders diagram inline
4. Right-click diagram → Save as SVG/PNG

### D2 Diagrams

```bash
# Install D2
brew install d2  # macOS
curl -fsSL https://d2lang.com/install.sh | sh -s --  # Linux

# Render with different themes
d2 --theme=0 diagram.d2 output.svg    # Neutral default
d2 --theme=200 diagram.d2 output.svg  # Terminal
d2 --theme=201 diagram.d2 output.svg  # Cool classics

# High resolution export
d2 --pad=40 diagram.d2 output.svg
```

---

## Integration with Reveal.js Presentation

Add diagrams to your existing `presentation/index.html`:

### Method 1: Embed Mermaid Directly

```html
<section>
  <h2>Architecture Overview</h2>
  <div class="mermaid">
    <!-- Paste Mermaid diagram code here -->
    flowchart TB
      Start([Developer Push]) --> GHA[GitHub Actions]
      <!-- ... rest of diagram ... -->
  </div>
</section>

<!-- Add Mermaid plugin at end of file -->
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```

### Method 2: Use SVG Export

```html
<section>
  <h2>Architecture Overview</h2>
  <img src="assets/images/architecture-flow.svg"
       alt="CI/CD Pipeline Architecture"
       style="background: white; padding: 20px;">
</section>
```

### Method 3: Progressive Reveal

```html
<section>
  <h2>Deployment Coordination</h2>
  <img src="assets/images/architecture-flow.svg" class="fragment">
  <div class="fragment">
    <h3>Key Benefits:</h3>
    <ul>
      <li class="fragment">Database schema validated before deployment</li>
      <li class="fragment">Application always compatible with current schema</li>
      <li class="fragment">Automated rollback on any failure</li>
    </ul>
  </div>
</section>
```

---

## Recommendations

### For Different Audiences

| Audience | Recommended Diagram | Why |
|----------|-------------------|-----|
| **Executives** | C4 Context Diagram | Shows big picture, system boundaries, minimal technical detail |
| **Technical Architects** | CI/CD Pipeline Flow | Shows complete automation workflow, decision points, quality gates |
| **DevOps Engineers** | Sequence Diagram | Shows time-based orchestration, system interactions, coordination |
| **Marketing/Sales** | D2 Diagram (modern style) | Contemporary aesthetics, visual appeal, easy to understand |

### For Different Presentation Contexts

| Context | Format | Approach |
|---------|--------|----------|
| **Live Demo** | Mermaid in Reveal.js | Interactive, can zoom/highlight sections |
| **PDF Report** | SVG export (high-res) | Crisp at any zoom level, small file size |
| **PowerPoint** | PNG export (2400x1600) | High resolution, works everywhere |
| **Documentation** | Mermaid in markdown | Version controlled, renders on GitHub |
| **Blog Post** | D2 SVG export | Modern look, professional appearance |

### Multi-Diagram Strategy

For a comprehensive presentation, use this progression:

1. **Slide 1**: C4 Context Diagram
   - "Here's what we built - the big picture"

2. **Slide 2**: CI/CD Pipeline Flow
   - "Here's how it works - the automation journey"

3. **Slide 3**: Sequence Diagram (zoom into one environment)
   - "Here's the coordination pattern - database first, then app"

4. **Slide 4**: Results/Benefits
   - Screenshots, metrics, customer impact

---

## Customization Tips

### Changing Colors

**Mermaid (Theme Variables):**
```
%%{init: {'themeVariables': {
  'primaryColor':'#YOUR_COLOR',
  'primaryBorderColor':'#YOUR_BORDER',
  'lineColor':'#YOUR_LINE'
}}}%%
```

**D2 (Style Overrides):**
```d2
object: {
  style.fill: "#YOUR_COLOR"
  style.stroke: "#YOUR_BORDER"
}
```

### Adding Your Branding

1. **Export to SVG**
2. **Open in Figma/Illustrator/Inkscape**
3. **Add logo, adjust colors, refine layout**
4. **Export final version**

### Simplifying for Time Constraints

If presenting to a time-constrained audience:
- **Remove**: Test/validation steps
- **Keep**: Database → App coordination
- **Emphasize**: "Schema updated before app deployed"

---

## Quick Start

**To get a customer-ready diagram in 2 minutes:**

1. Copy the **CI/CD Pipeline Flow** Mermaid code above
2. Go to https://mermaid.live
3. Paste the code
4. Click "Download PNG" (or SVG for higher quality)
5. Add to your presentation deck

**Result:** Professional architecture diagram ready for customer presentation.

---

## Questions?

- **Can't decide which diagram?** → Use the CI/CD Pipeline Flow (most comprehensive)
- **Need to edit/customize?** → Mermaid Live Editor is easiest
- **Want modern aesthetics?** → Try D2 diagrams
- **Presenting in 5 minutes?** → Export PNG from Mermaid Live, drop in slides
- **Need high resolution?** → Export SVG (infinite resolution) or 2400x1600 PNG

For more details on the architecture, see [CLAUDE.md](../CLAUDE.md).
