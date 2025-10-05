"""
Pytest configuration and fixtures for Bagel Store tests.
"""

import os
import pytest
import time
import psycopg2
from pathlib import Path
from dotenv import load_dotenv
from playwright.sync_api import Page, expect
import requests

# Load environment variables from .env file
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(dotenv_path=env_path)

# Application configuration
APP_URL = "http://localhost:5001"
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "database": "dev",
    "user": "postgres",
    "password": "postgres"
}

# Demo credentials from environment variables
DEMO_USERNAME = os.getenv('DEMO_USERNAME', 'demo')
DEMO_PASSWORD = os.getenv('DEMO_PASSWORD')

if not DEMO_PASSWORD:
    raise ValueError(
        "DEMO_PASSWORD environment variable not set! "
        "Please copy .env.example to .env and set your credentials."
    )


@pytest.fixture(scope="session")
def wait_for_services():
    """Wait for Docker Compose services to be healthy before running tests."""
    max_retries = 30
    retry_delay = 2

    print("\n🔍 Waiting for services to be ready...")

    # Wait for Flask app
    for i in range(max_retries):
        try:
            response = requests.get(f"{APP_URL}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                if data.get("status") == "healthy" and data.get("database") == "connected":
                    print("✅ Flask app is healthy")
                    break
        except (requests.ConnectionError, requests.Timeout):
            if i == max_retries - 1:
                raise Exception("Flask app did not become healthy in time")
            time.sleep(retry_delay)

    # Wait for PostgreSQL
    for i in range(max_retries):
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            conn.close()
            print("✅ PostgreSQL is ready")
            break
        except psycopg2.OperationalError:
            if i == max_retries - 1:
                raise Exception("PostgreSQL did not become ready in time")
            time.sleep(retry_delay)

    print("🚀 All services ready for testing\n")


@pytest.fixture(scope="function")
def db_connection():
    """Provide a database connection for tests that need to validate DB state."""
    conn = psycopg2.connect(**DB_CONFIG)
    yield conn
    conn.close()


@pytest.fixture(scope="function")
def clean_cart(page: Page):
    """Clear session cart before each test."""
    # Navigate to app to establish session
    page.goto(APP_URL)
    # Clear cookies/session storage to reset cart
    page.context.clear_cookies()
    page.context.storage_state()


@pytest.fixture(scope="function")
def authenticated_page(page: Page):
    """Provide an authenticated page session."""
    page.goto(f"{APP_URL}/login")
    page.fill('#username', DEMO_USERNAME)
    page.fill('#password', DEMO_PASSWORD)
    page.click('button[type="submit"]')

    # Wait for redirect to homepage
    page.wait_for_url(APP_URL + "/", timeout=10000)

    # Verify login succeeded by checking for welcome message
    expect(page.locator(f'text=Welcome, {DEMO_USERNAME}!')).to_be_visible(timeout=10000)

    return page


@pytest.fixture(scope="function")
def clean_test_orders(db_connection):
    """Clean up test orders after tests."""
    yield
    # Cleanup after test
    cursor = db_connection.cursor()
    try:
        # Delete recent test orders (created within last minute)
        cursor.execute("""
            DELETE FROM order_items
            WHERE order_id IN (
                SELECT id FROM orders
                WHERE order_date > NOW() - INTERVAL '1 minute'
            )
        """)
        cursor.execute("""
            DELETE FROM orders
            WHERE order_date > NOW() - INTERVAL '1 minute'
        """)
        db_connection.commit()
    finally:
        cursor.close()


@pytest.fixture(scope="session", autouse=True)
def browser_context_args(browser_context_args, wait_for_services):
    """Configure browser context with appropriate settings."""
    return {
        **browser_context_args,
        "viewport": {"width": 1280, "height": 720},
        "ignore_https_errors": True,
    }
