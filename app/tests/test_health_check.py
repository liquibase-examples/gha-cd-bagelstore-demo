"""
Health check and system status tests.
"""

import pytest
import requests
from playwright.sync_api import Page, expect


APP_URL = "http://localhost:5001"


@pytest.mark.health
def test_health_endpoint_returns_healthy():
    """Test that /health endpoint returns correct JSON."""
    response = requests.get(f"{APP_URL}/health")

    assert response.status_code == 200
    data = response.json()

    assert data["status"] == "healthy"
    assert data["database"] == "connected"


@pytest.mark.health
def test_health_endpoint_via_browser(page: Page):
    """Test health endpoint accessibility via browser."""
    page.goto(f"{APP_URL}/health")

    # Page should contain JSON response
    content = page.content()
    assert '"status"' in content
    assert '"healthy"' in content
    assert '"database"' in content
    assert '"connected"' in content


@pytest.mark.health
def test_database_connection(db_connection):
    """Test direct database connectivity."""
    cursor = db_connection.cursor()

    # Verify we can query the database
    cursor.execute("SELECT COUNT(*) FROM products")
    result = cursor.fetchone()

    assert result is not None
    assert result[0] == 5  # Should have 5 bagel products

    cursor.close()


@pytest.mark.health
def test_database_has_sample_data(db_connection):
    """Verify database is initialized with sample data."""
    cursor = db_connection.cursor()

    # Check products table
    cursor.execute("SELECT COUNT(*) FROM products")
    assert cursor.fetchone()[0] == 5

    # Check inventory table
    cursor.execute("SELECT COUNT(*) FROM inventory")
    assert cursor.fetchone()[0] == 5

    # Verify each product has inventory
    cursor.execute("""
        SELECT p.name, i.quantity
        FROM products p
        JOIN inventory i ON p.id = i.product_id
        ORDER BY p.name
    """)
    inventory = cursor.fetchall()

    assert len(inventory) == 5
    for product_name, quantity in inventory:
        assert quantity >= 45  # Should have at least 45 units (may be consumed by other tests)

    cursor.close()
