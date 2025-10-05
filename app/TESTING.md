# Bagel Store - Local Development & Testing Guide

This guide covers local development, testing, and troubleshooting for the Flask Bagel Store application.

## Quick Start

```bash
# Build and run application with PostgreSQL
cd app
docker compose up --build

# Access the application
open http://localhost:5001

# View logs
docker compose logs -f app

# Stop and clean up
docker compose down
```

## Architecture

### Local Development Environment
```
┌─────────────────┐         ┌──────────────────┐
│  Flask App      │ ←────→  │  PostgreSQL      │
│  localhost:5001 │         │  localhost:5432  │
│  (Docker)       │         │  (Docker)        │
└─────────────────┘         └──────────────────┘
         ↑
         │
    Playwright
    Browser Tests
```

### Components
- **Flask App Container**: Python 3.11 with Flask 3.0, runs on port 5000 (mapped to 5001 externally)
- **PostgreSQL Container**: PostgreSQL 16, initialized with schema and sample data
- **Network**: `bagel-network` (Docker bridge network for inter-container communication)

## Port Configuration

**Important:** The application uses different ports internally vs externally due to macOS port conflicts.

| Service | Internal Port | External Port | Reason |
|---------|--------------|---------------|---------|
| Flask App | 5000 | 5001 | macOS ControlCenter uses port 5000 for AirPlay Receiver |
| PostgreSQL | 5432 | 5432 | Standard PostgreSQL port |

**Access URLs:**
- Application: http://localhost:5001
- Health Check: http://localhost:5001/health
- PostgreSQL: `localhost:5432` (from host) or `postgres:5432` (from app container)

## Python Module Imports

### Docker Context and Import Patterns

The Docker container runs Python from the `/app/src/` directory, which affects how imports work:

**Container Structure:**
```
/app/
├── src/
│   ├── app.py          # Application factory
│   ├── routes.py       # Route handlers
│   ├── database.py     # Database utilities
│   ├── models.py       # Data models
│   └── templates/      # Jinja2 templates
├── pyproject.toml      # Dependencies
└── uv.lock            # Locked versions
```

**Import Rules:**
```python
# ✅ CORRECT - Use relative imports
from routes import bp
from database import execute_query, get_db_connection
from models import Product, Order, OrderItem

# ❌ WRONG - Absolute imports fail in Docker
from src.routes import bp
from src.database import execute_query
```

**Why?** The `WORKDIR` is `/app` and Python runs from `/app/src/`, so `src` is not in the module path.

**After changing imports:**
```bash
# Must rebuild without cache to clear Docker layers
docker compose build --no-cache
docker compose up
```

## Authentication

### Demo Credentials
- **Username:** `demo`
- **Password:** `B@gelSt0re2025!Demo`

**Security Notes:**
- Password is 20 characters with mixed case, numbers, and special characters
- Secure enough for public hosting
- Hardcoded in `app/src/routes.py` (DEMO_USER constant)
- Displayed on login page for demo purposes

**Files to Update:**
- `app/src/routes.py` - Line 12: `DEMO_USER` dictionary
- `app/src/templates/login.html` - Line 30: Demo credentials display

## Database

### Schema
The database is automatically initialized with `init-db.sql`:

**Tables:**
- `products` - Bagel types (id, name, description, price)
- `inventory` - Stock levels (product_id, quantity, last_updated)
- `orders` - Customer orders (id, order_date, total_amount, status)
- `order_items` - Order line items (order_id, product_id, quantity, price)

**Sample Data:**
- 5 bagel products (Plain, Everything, Blueberry, Cinnamon Raisin, Asiago)
- 50 units of inventory per product
- Prices range from $2.50 to $3.50

### Database Access

**From Host:**
```bash
psql postgresql://postgres:postgres@localhost:5432/dev
```

**From App Container:**
```bash
docker compose exec app python -c "
from database import execute_query
products = execute_query('SELECT * FROM products')
print(products)
"
```

## Testing

### Manual Testing Checklist

1. **Homepage** (http://localhost:5001)
   - [ ] All 5 bagel products display
   - [ ] Prices are correct
   - [ ] Descriptions are readable

2. **Shopping Cart**
   - [ ] Add item to cart (click "Add to Cart")
   - [ ] Cart count updates in navigation
   - [ ] Cart page shows correct items and total
   - [ ] Remove item works

3. **Authentication**
   - [ ] Login page displays demo credentials
   - [ ] Login with correct credentials succeeds
   - [ ] Login with wrong credentials shows error
   - [ ] Navigation shows "Welcome, demo!" after login
   - [ ] Logout works and redirects to homepage

4. **Checkout Flow**
   - [ ] Checkout redirects to login if not authenticated
   - [ ] Checkout shows order summary when authenticated
   - [ ] "Place Order" creates order in database
   - [ ] Order confirmation page displays order details
   - [ ] Cart is cleared after order placement

5. **Health Check**
   - [ ] /health returns `{"status": "healthy", "database": "connected"}`

### Automated Testing with pytest + Playwright

The project includes comprehensive end-to-end tests using pytest and Playwright.

#### Prerequisites

1. **Install dependencies:**
   ```bash
   cd app
   uv sync --extra dev
   ```

2. **Install Playwright browsers:**
   ```bash
   uv run playwright install chromium
   ```

3. **Start Docker Compose services:**
   ```bash
   docker compose up -d
   ```

#### Running Tests

**Run all tests:**
```bash
uv run pytest
```

**Run with visible browser (headed mode):**
```bash
uv run pytest --headed
```

**Run specific test file:**
```bash
uv run pytest tests/test_health_check.py
uv run pytest tests/test_e2e_shopping.py
```

**Run tests by marker:**
```bash
uv run pytest -m health        # Health check tests only
uv run pytest -m e2e           # End-to-end tests only
uv run pytest -m "not slow"    # Skip slow tests
```

**Run specific test:**
```bash
uv run pytest tests/test_e2e_shopping.py::test_complete_checkout_flow
```

**Verbose output:**
```bash
uv run pytest -v
```

#### Test Structure

```
app/tests/
├── conftest.py              # Fixtures and configuration
├── test_health_check.py     # Health endpoint and DB connectivity tests
└── test_e2e_shopping.py     # End-to-end shopping flow tests
```

#### Available Test Fixtures

- `wait_for_services` - Waits for Docker Compose services to be healthy
- `db_connection` - Provides PostgreSQL connection for DB validation
- `clean_cart` - Clears session cart before each test
- `authenticated_page` - Provides logged-in browser session
- `clean_test_orders` - Cleanup test orders after tests

#### Test Coverage

**Health Tests:**
- ✅ Health endpoint returns correct JSON
- ✅ Database connectivity
- ✅ Sample data initialization

**E2E Shopping Tests:**
- ✅ Homepage displays all 5 products
- ✅ Add item to cart
- ✅ View cart page
- ✅ Remove item from cart
- ✅ Multiple items in cart
- ✅ Product prices displayed
- ✅ Login success
- ✅ Login failure
- ✅ Logout
- ✅ Checkout requires authentication
- ✅ Complete checkout flow (login → cart → checkout → order confirmation)
- ✅ Order creation in database
- ✅ Cart cleared after order

#### CI/CD Integration

**Future Enhancement:** Add automated tests to GitHub Actions workflow:

```yaml
- name: Install dependencies
  run: |
    uv sync --extra dev
    uv run playwright install --with-deps chromium

- name: Start services
  run: docker compose up -d

- name: Wait for services
  run: sleep 10

- name: Run tests
  run: uv run pytest --tb=short

- name: Stop services
  run: docker compose down
```

#### Troubleshooting Tests

**Services not ready:**
- Ensure Docker Compose is running: `docker compose ps`
- Check logs: `docker compose logs app postgres`
- Restart services: `docker compose restart`

**Playwright browser not installed:**
```bash
uv run playwright install chromium
```

**Test failures:**
- Run with verbose output: `pytest -v`
- See full traceback: `pytest --tb=long`
- Run single test to isolate issue

**Port conflicts:**
- Ensure nothing else is using port 5001: `lsof -i :5001`
- Ensure PostgreSQL port 5432 is available: `lsof -i :5432`

## Common Development Commands

### Docker Commands
```bash
# Start services in background
docker compose up -d

# View all logs
docker compose logs

# View specific service logs
docker compose logs -f app
docker compose logs -f postgres

# Restart a service
docker compose restart app

# Execute command in container
docker compose exec app python -c "print('Hello')"
docker compose exec postgres psql -U postgres -d dev

# Rebuild after code changes
docker compose up --build

# Rebuild without cache (needed after import changes)
docker compose build --no-cache

# Stop services
docker compose stop

# Stop and remove containers
docker compose down

# Stop and remove containers + volumes
docker compose down -v
```

### Python/uv Commands

**From Host (requires uv installed):**
```bash
cd app

# Sync dependencies
uv sync

# Add new dependency
uv add flask-cors

# Run app locally (without Docker)
uv run python main.py

# Run tests
uv run pytest
```

### Database Commands
```bash
# Connect to database
docker compose exec postgres psql -U postgres -d dev

# Run SQL query
docker compose exec postgres psql -U postgres -d dev -c "SELECT * FROM products;"

# Backup database
docker compose exec postgres pg_dump -U postgres dev > backup.sql

# Restore database
docker compose exec -T postgres psql -U postgres -d dev < backup.sql
```

## Troubleshooting

### ModuleNotFoundError: No module named 'src'

**Symptom:**
```
ModuleNotFoundError: No module named 'src'
```

**Cause:** Using absolute imports (`from src.routes`) instead of relative imports in Docker context.

**Fix:**
1. Change imports to relative: `from routes import bp`
2. Rebuild without cache: `docker compose build --no-cache`
3. Restart: `docker compose up`

**Files to check:**
- `app/src/app.py`
- `app/src/routes.py`

---

### Port 5000 Already in Use

**Symptom:**
```
bind: address already in use
```

**Cause:** macOS ControlCenter uses port 5000 for AirPlay Receiver.

**Fix:** Already handled in `docker-compose.yml`:
```yaml
ports:
  - "5001:5000"  # External:Internal
```

Access app at http://localhost:5001 (not 5000).

**To check what's using a port:**
```bash
lsof -i :5000 | grep LISTEN
```

---

### Docker Cache Issues

**Symptom:** Code changes not reflected in running container.

**Fix:**
```bash
# Stop containers
docker compose down

# Rebuild without cache
docker compose build --no-cache

# Start fresh
docker compose up
```

---

### Database Connection Errors

**Symptom:**
```
could not connect to server: Connection refused
```

**Fix:**
1. Ensure PostgreSQL container is healthy:
   ```bash
   docker compose ps
   # Look for "healthy" status on postgres service
   ```

2. Check PostgreSQL logs:
   ```bash
   docker compose logs postgres
   ```

3. Restart database:
   ```bash
   docker compose restart postgres
   ```

---

### Playwright "Ref not found" Errors

**Symptom:**
```
Error: Ref e16 not found in the current page snapshot
```

**Cause:** Page state changed between snapshot and interaction.

**Fix:** Take a fresh snapshot before interacting:
```python
browser.snapshot()  # Fresh snapshot
browser.type("element", "text")  # Then interact
```

---

### Flask App Crashes on Startup

**Common Causes:**
1. **Missing dependencies** - Run `uv sync` and rebuild
2. **Import errors** - Check relative vs absolute imports
3. **Database not ready** - Check healthcheck in docker-compose.yml

**Debug steps:**
```bash
# View detailed logs
docker compose logs app

# Check if database is ready
docker compose exec postgres pg_isready

# Rebuild and restart
docker compose down
docker compose up --build
```

---

### Permission Denied Errors

**Symptom:**
```
ERROR: permission denied while trying to connect to Docker daemon
```

**Fix:** Ensure Docker daemon is running and user has permissions:
```bash
# macOS - ensure Docker Desktop is running
open -a Docker

# Linux - add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## CI/CD Integration

This local setup mirrors the CI/CD environment:

| Component | Local | CI/CD |
|-----------|-------|-------|
| App Image | Built locally via `docker compose` | Built in GitHub Actions, pushed to ghcr.io |
| Database | PostgreSQL 16 container | AWS RDS PostgreSQL (shared, 4 databases) |
| Secrets | Hardcoded in `docker-compose.yml` | AWS Secrets Manager |
| Port | 5001 (external) | App Runner assigns dynamically |

**Testing locally ensures:**
- Docker image builds successfully
- Database schema works correctly
- Application routes function properly
- Environment variables are configured correctly

## Next Steps

After local testing succeeds:
1. Commit changes to feature branch
2. Create pull request
3. GitHub Actions runs Liquibase policy checks
4. Merge to main triggers deployment to dev
5. Manual promotion through test → staging → prod via Harness

## Additional Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [uv Documentation](https://docs.astral.sh/uv/)
- [Playwright Documentation](https://playwright.dev/)
