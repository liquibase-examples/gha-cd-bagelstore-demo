"""
Database connection and query utilities.
"""

import os
import psycopg2
from psycopg2.extras import DictCursor
from contextlib import contextmanager


def get_db_url():
    """Get database URL from environment variable or build from components"""
    # Option 1: Use DATABASE_URL if provided (local development)
    if os.environ.get('DATABASE_URL'):
        return os.environ.get('DATABASE_URL')

    # Option 2: Build from individual components (AWS deployment with Secrets Manager)
    db_username = os.environ.get('DB_USERNAME')
    db_password = os.environ.get('DB_PASSWORD')
    db_host = os.environ.get('DB_HOST')
    db_port = os.environ.get('DB_PORT', '5432')
    db_name = os.environ.get('DB_NAME')

    if all([db_username, db_password, db_host, db_name]):
        return f'postgresql://{db_username}:{db_password}@{db_host}:{db_port}/{db_name}'

    # Fallback for local development
    return 'postgresql://postgres:postgres@localhost:5432/dev'


@contextmanager
def get_db_connection():
    """Context manager for database connections"""
    conn = psycopg2.connect(get_db_url())
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@contextmanager
def get_db_cursor(conn):
    """Context manager for database cursors"""
    cursor = conn.cursor(cursor_factory=DictCursor)
    try:
        yield cursor
    finally:
        cursor.close()


def execute_query(query, params=None, fetch=True):
    """Execute a database query and return results"""
    with get_db_connection() as conn:
        with get_db_cursor(conn) as cursor:
            cursor.execute(query, params or ())
            if fetch:
                return cursor.fetchall()
            return None


def execute_one(query, params=None):
    """Execute a query and return a single result"""
    with get_db_connection() as conn:
        with get_db_cursor(conn) as cursor:
            cursor.execute(query, params or ())
            return cursor.fetchone()
