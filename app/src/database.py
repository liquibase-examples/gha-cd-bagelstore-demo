"""
Database connection and query utilities.
"""

import os
import psycopg2
from psycopg2.extras import DictCursor
from contextlib import contextmanager


def get_db_url():
    """Get database URL from environment variable"""
    return os.environ.get('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/dev')


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
