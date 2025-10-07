<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bagel Store Demo Dashboard - ${demo_id}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        h1 {
            color: #2d3748;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .subtitle {
            color: #718096;
            font-size: 1.1em;
        }
        .mode-badge {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: bold;
            margin-top: 15px;
            font-size: 0.9em;
        }
        .mode-aws {
            background: #f97316;
            color: white;
        }
        .mode-local {
            background: #22c55e;
            color: white;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .card h2 {
            color: #2d3748;
            margin-bottom: 20px;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .icon {
            font-size: 1.5em;
        }
        .env-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
        }
        .env-card {
            background: #f7fafc;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid;
        }
        .env-dev { border-color: #10b981; }
        .env-test { border-color: #3b82f6; }
        .env-staging { border-color: #f59e0b; }
        .env-prod { border-color: #ef4444; }
        .env-card h3 {
            color: #2d3748;
            margin-bottom: 10px;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 1px;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 500;
            transition: all 0.3s;
            margin-top: 10px;
        }
        .btn:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        }
        .btn-secondary {
            background: #718096;
        }
        .btn-secondary:hover {
            background: #4a5568;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #e2e8f0;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .info-label {
            color: #718096;
            font-weight: 500;
        }
        .info-value {
            color: #2d3748;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }
        .code {
            background: #1a202c;
            color: #a0aec0;
            padding: 15px;
            border-radius: 6px;
            font-family: 'Courier New', monospace;
            font-size: 0.85em;
            overflow-x: auto;
            margin-top: 10px;
        }
        .code .highlight {
            color: #f687b3;
        }
        .full-width {
            grid-column: 1 / -1;
        }
        footer {
            text-align: center;
            color: white;
            padding: 20px;
            font-size: 0.9em;
        }
        a {
            color: inherit;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🥯 Bagel Store Demo Dashboard</h1>
            <p class="subtitle">Demo ID: <strong>${demo_id}</strong> | Region: <strong>${aws_region}</strong></p>
            <span class="mode-badge mode-${deployment_mode}">${deployment_mode == "aws" ? "☁️ AWS Mode" : "🐳 Local Mode"}</span>
        </header>

        <div class="grid">
            <!-- Application URLs -->
            <div class="card">
                <h2><span class="icon">🌐</span> Application URLs</h2>
                <div class="env-grid">
                    %{ for env, url in app_urls ~}
                    <div class="env-card env-${env}">
                        <h3>${env}</h3>
                        <a href="${url}" class="btn" target="_blank">Open App</a>
                        <div style="margin-top:10px;font-size:0.85em;color:#718096">${url}</div>
                    </div>
                    %{ endfor ~}
                </div>
            </div>

            <!-- Database Connections -->
            <div class="card">
                <h2><span class="icon">🗄️</span> Database Connections</h2>
                <div class="info-row">
                    <span class="info-label">Endpoint:</span>
                    <span class="info-value">${rds_endpoint}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Username:</span>
                    <span class="info-value">${rds_username}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Password:</span>
                    <span class="info-value">${deployment_mode == "aws" ? "Stored in AWS Secrets Manager" : "postgres"}</span>
                </div>
                %{ if deployment_mode == "local" ~}
                <div class="code">
<span class="highlight"># Connect to local databases</span>
psql -h localhost -p 5432 -U postgres -d dev
psql -h localhost -p 5433 -U postgres -d test
psql -h localhost -p 5434 -U postgres -d staging
psql -h localhost -p 5435 -U postgres -d prod
                </div>
                %{ endif ~}
            </div>

            <!-- Harness CD Pipeline -->
            <div class="card">
                <h2><span class="icon">⚙️</span> Harness CD Pipeline</h2>
                <div class="info-row">
                    <span class="info-label">Account:</span>
                    <span class="info-value">${harness_account_id}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Project:</span>
                    <span class="info-value">${harness_project_id}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Pipeline:</span>
                    <span class="info-value">${harness_pipeline_id}</span>
                </div>
                <a href="https://app.harness.io/ng/account/${harness_account_id}/cd/orgs/${harness_org_id}/projects/${harness_project_id}/pipelines/${harness_pipeline_id}/pipeline-studio/"
                   class="btn" target="_blank">Open Pipeline Studio</a>
                <a href="https://app.harness.io/ng/account/${harness_account_id}/cd/orgs/${harness_org_id}/projects/${harness_project_id}/pipelines/${harness_pipeline_id}/deployments"
                   class="btn btn-secondary" target="_blank">View Deployments</a>
            </div>

            <!-- GitHub Repository -->
            <div class="card">
                <h2><span class="icon">📦</span> GitHub Repository</h2>
                <div class="info-row">
                    <span class="info-label">Organization:</span>
                    <span class="info-value">${github_org}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Repository:</span>
                    <span class="info-value">${github_repo}</span>
                </div>
                <a href="https://github.com/${github_org}/${github_repo}"
                   class="btn" target="_blank">Open Repository</a>
                <a href="https://github.com/${github_org}/${github_repo}/actions"
                   class="btn btn-secondary" target="_blank">View Actions</a>
                <a href="https://github.com/${github_org}/${github_repo}/pulls"
                   class="btn btn-secondary" target="_blank">Pull Requests</a>
            </div>

            <!-- JDBC URLs -->
            <div class="card full-width">
                <h2><span class="icon">🔌</span> JDBC Connection Strings</h2>
                <div class="env-grid">
                    %{ for env, jdbc_url in jdbc_urls ~}
                    <div class="env-card env-${env}">
                        <h3>${env}</h3>
                        <div class="code" style="margin-top:10px">${jdbc_url}</div>
                    </div>
                    %{ endfor ~}
                </div>
            </div>

            %{ if deployment_mode == "aws" ~}
            <!-- AWS Resources -->
            <div class="card full-width">
                <h2><span class="icon">☁️</span> AWS Resources</h2>
                <div class="info-row">
                    <span class="info-label">Liquibase Flows Bucket:</span>
                    <span class="info-value">${s3_flows_bucket}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Operation Reports Bucket:</span>
                    <span class="info-value">${s3_reports_bucket}</span>
                </div>
                <a href="https://console.aws.amazon.com/rds/home?region=${aws_region}"
                   class="btn" target="_blank">RDS Console</a>
                <a href="https://console.aws.amazon.com/apprunner/home?region=${aws_region}"
                   class="btn btn-secondary" target="_blank">App Runner Console</a>
                <a href="https://s3.console.aws.amazon.com/s3/buckets/${s3_flows_bucket}?region=${aws_region}"
                   class="btn btn-secondary" target="_blank">Flows Bucket</a>
            </div>
            %{ endif ~}

            %{ if deployment_mode == "local" ~}
            <!-- Local Deployment Commands -->
            <div class="card full-width">
                <h2><span class="icon">🐳</span> Local Deployment Commands</h2>
                <div class="code">
<span class="highlight"># Start all environments</span>
docker compose -f docker-compose-demo.yml up -d

<span class="highlight"># View deployment state</span>
./scripts/show-deployment-state.sh

<span class="highlight"># View logs</span>
docker compose -f docker-compose-demo.yml logs -f app-dev

<span class="highlight"># Stop all</span>
docker compose -f docker-compose-demo.yml down
                </div>
            </div>
            %{ endif ~}

            <!-- Demo Workflow -->
            <div class="card full-width">
                <h2><span class="icon">🎬</span> Demo Workflow</h2>
                <ol style="line-height:2; color:#2d3748">
                    <li><strong>Create a Branch:</strong> Make changes to database changelog or application code</li>
                    <li><strong>Open Pull Request:</strong> GitHub Actions runs Liquibase policy checks automatically</li>
                    <li><strong>Review Checks:</strong> See 12 quality checks enforced at BLOCKER severity</li>
                    <li><strong>Merge to Main:</strong> Triggers artifact creation (Docker image + changelog bundle)</li>
                    <li><strong>Trigger Harness:</strong> Webhook starts deployment pipeline</li>
                    <li><strong>Deploy to Dev:</strong> Harness runs Liquibase update, then deploys application</li>
                    <li><strong>Promote Through Stages:</strong> Test → Staging → Production with approval gates</li>
                    <li><strong>Verify Deployments:</strong> Check each environment using links above</li>
                </ol>
            </div>
        </div>

        <footer>
            Generated by Terraform | Demo ID: ${demo_id} | ${deployment_mode == "aws" ? "AWS Deployment" : "Local Deployment"}
        </footer>
    </div>
</body>
</html>
