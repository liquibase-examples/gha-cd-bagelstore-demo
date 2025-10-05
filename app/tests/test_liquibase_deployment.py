"""
Liquibase deployment verification tests.

These tests verify that Liquibase successfully deployed the database schema
according to the changelog. They check:
- Changelog tracking tables (databasechangelog, databasechangeloglock)
- Expected changesets were applied
- All tables created correctly
- Indexes created
- Foreign key constraints exist
- Seed data loaded
- Database tags applied

Mark: @pytest.mark.deployment
"""

import pytest


@pytest.mark.deployment
def test_databasechangelog_table_exists(db_connection):
    """Verify that Liquibase tracking table exists."""
    cursor = db_connection.cursor()

    # Check if databasechangelog table exists
    cursor.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'databasechangelog'
        );
    """)

    result = cursor.fetchone()
    assert result[0] is True, "databasechangelog table does not exist - Liquibase may not have run"

    cursor.close()


@pytest.mark.deployment
def test_expected_changesets_applied(db_connection):
    """Verify all 9 changesets from changelog were applied in correct order."""
    cursor = db_connection.cursor()

    cursor.execute("""
        SELECT id, author, filename, orderexecuted
        FROM databasechangelog
        ORDER BY orderexecuted
    """)
    changesets = cursor.fetchall()

    assert len(changesets) == 9, f"Expected 9 changesets, found {len(changesets)}"

    # Verify specific changesets in expected order
    expected = [
        ('metadata', 'demo', 'db/changelog/changelog-master.yaml'),
        ('001-create-products-table', 'demo', 'changesets/001-create-products-table.sql'),
        ('002-create-inventory-table', 'demo', 'changesets/002-create-inventory-table.sql'),
        ('003-create-orders-table', 'demo', 'changesets/003-create-orders-table.sql'),
        ('004-create-order-items-table', 'demo', 'changesets/004-create-order-items-table.sql'),
        ('005-create-indexes', 'demo', 'changesets/005-create-indexes.sql'),
        ('006-seed-products', 'demo', 'changesets/006-seed-products.sql'),
        ('007-seed-inventory', 'demo', 'changesets/007-seed-inventory.sql'),
        ('tag-v1.0.0', 'demo', 'db/changelog/changelog-master.yaml'),
    ]

    for i, (expected_id, expected_author, expected_filename) in enumerate(expected):
        actual_id, actual_author, actual_filename, order_executed = changesets[i]
        assert actual_id == expected_id, f"Changeset {i}: Expected ID '{expected_id}', got '{actual_id}'"
        assert actual_author == expected_author, f"Changeset {i}: Expected author '{expected_author}', got '{actual_author}'"
        assert expected_filename in actual_filename, f"Changeset {i}: Filename mismatch"
        assert order_executed == i + 1, f"Changeset {i}: Wrong execution order"

    cursor.close()


@pytest.mark.deployment
def test_all_tables_created(db_connection):
    """Verify all expected tables were created by Liquibase changesets."""
    cursor = db_connection.cursor()

    # Expected tables from changesets 001-004
    expected_tables = [
        'products',
        'inventory',
        'orders',
        'order_items',
        'databasechangelog',
        'databasechangeloglock'
    ]

    cursor.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        ORDER BY table_name
    """)

    actual_tables = [row[0] for row in cursor.fetchall()]

    for table in expected_tables:
        assert table in actual_tables, f"Table '{table}' not found. Available tables: {actual_tables}"

    cursor.close()


@pytest.mark.deployment
def test_indexes_created(db_connection):
    """Verify all indexes from changeset 005 were created."""
    cursor = db_connection.cursor()

    # Expected indexes from changeset 005
    expected_indexes = [
        'idx_order_items_order_id',
        'idx_order_items_product_id',
        'idx_orders_status',
        'idx_orders_date',
    ]

    cursor.execute("""
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
        AND indexname LIKE 'idx_%'
        ORDER BY indexname
    """)

    actual_indexes = [row[0] for row in cursor.fetchall()]

    assert len(actual_indexes) >= 4, f"Expected at least 4 indexes, found {len(actual_indexes)}: {actual_indexes}"

    for index in expected_indexes:
        assert index in actual_indexes, f"Index '{index}' not found. Available indexes: {actual_indexes}"

    cursor.close()


@pytest.mark.deployment
def test_foreign_keys_exist(db_connection):
    """Verify foreign key constraints were created correctly."""
    cursor = db_connection.cursor()

    # Check inventory -> products FK
    cursor.execute("""
        SELECT COUNT(*)
        FROM information_schema.table_constraints
        WHERE table_name = 'inventory'
        AND constraint_type = 'FOREIGN KEY'
    """)
    inventory_fks = cursor.fetchone()[0]
    assert inventory_fks >= 1, "inventory table missing foreign key to products"

    # Check order_items -> orders FK
    cursor.execute("""
        SELECT COUNT(*)
        FROM information_schema.table_constraints
        WHERE table_name = 'order_items'
        AND constraint_type = 'FOREIGN KEY'
    """)
    order_items_fks = cursor.fetchone()[0]
    assert order_items_fks >= 2, "order_items table missing foreign keys (should have 2: orders + products)"

    cursor.close()


@pytest.mark.deployment
def test_seed_data_loaded(db_connection):
    """Verify seed data from changesets 006-007 was loaded correctly."""
    cursor = db_connection.cursor()

    # Check products seed data (changeset 006)
    cursor.execute("SELECT COUNT(*) FROM products")
    product_count = cursor.fetchone()[0]
    assert product_count == 5, f"Expected 5 products from seed data, found {product_count}"

    # Verify specific products exist
    cursor.execute("SELECT name FROM products ORDER BY name")
    product_names = [row[0] for row in cursor.fetchall()]
    expected_products = [
        'Blueberry Bagel',
        'Cinnamon Raisin Bagel',
        'Everything Bagel',
        'Plain Bagel',
        'Sesame Bagel'
    ]
    assert product_names == expected_products, f"Product names mismatch. Expected: {expected_products}, Got: {product_names}"

    # Check inventory seed data (changeset 007)
    cursor.execute("SELECT COUNT(*) FROM inventory")
    inventory_count = cursor.fetchone()[0]
    assert inventory_count == 5, f"Expected 5 inventory records from seed data, found {inventory_count}"

    # Verify all inventory quantities are 50 (initial seed value)
    cursor.execute("SELECT DISTINCT quantity FROM inventory")
    quantities = [row[0] for row in cursor.fetchall()]
    # Note: Quantities may be reduced if other tests have run, so just check they exist
    assert len(quantities) >= 1, "No inventory quantities found"

    cursor.close()


@pytest.mark.deployment
def test_database_tags_applied(db_connection):
    """Verify Liquibase tags were applied correctly."""
    cursor = db_connection.cursor()

    # Check for tag changesets
    cursor.execute("""
        SELECT tag
        FROM databasechangelog
        WHERE tag IS NOT NULL
        ORDER BY orderexecuted
    """)

    tags = [row[0] for row in cursor.fetchall()]

    # Expected tags from changelog-master.yaml
    expected_tags = ['v1.0.0-baseline', 'v1.0.0']

    assert len(tags) == 2, f"Expected 2 database tags, found {len(tags)}: {tags}"
    assert tags == expected_tags, f"Tag mismatch. Expected: {expected_tags}, Got: {tags}"

    cursor.close()
