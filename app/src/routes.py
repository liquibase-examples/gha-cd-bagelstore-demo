"""
Flask routes for the Bagel Store application.
"""

import os
from flask import Blueprint, render_template, request, redirect, url_for, session, jsonify
from database import execute_query, execute_one, get_db_connection, get_db_cursor
from models import Product, Order, OrderItem

bp = Blueprint('main', __name__)

# Demo user credentials from environment variables
# Set these in your .env file for local development
DEMO_USERNAME = os.getenv('DEMO_USERNAME')
DEMO_PASSWORD = os.getenv('DEMO_PASSWORD')

if not DEMO_USERNAME or not DEMO_PASSWORD:
    raise ValueError(
        "Demo credentials not configured! "
        "Please set DEMO_USERNAME and DEMO_PASSWORD environment variables. "
        "For local development, copy .env.example to .env and set your credentials."
    )


@bp.route('/')
def index():
    """Homepage - product catalog"""
    products = execute_query(
        'SELECT id, name, description, price FROM products ORDER BY name'
    )

    products_list = []
    if products:
        for row in products:
            products_list.append(Product.from_db_row(row))

    return render_template('index.html', products=products_list)


@bp.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        if username == DEMO_USERNAME and password == DEMO_PASSWORD:
            session['user'] = username
            return redirect(url_for('main.index'))
        else:
            return render_template('login.html', error='Invalid credentials')

    return render_template('login.html', demo_username=DEMO_USERNAME)


@bp.route('/logout')
def logout():
    """Logout"""
    session.pop('user', None)
    return redirect(url_for('main.index'))


@bp.route('/cart')
def cart():
    """Shopping cart"""
    cart_items = session.get('cart', [])

    # Fetch product details for cart items
    products = []
    total = 0.0

    for item in cart_items:
        product_row = execute_one(
            'SELECT id, name, description, price FROM products WHERE id = %s',
            (item['product_id'],)
        )
        if product_row:
            product = Product.from_db_row(product_row)
            products.append({
                'product': product,
                'quantity': item['quantity'],
                'subtotal': product.price * item['quantity']
            })
            total += product.price * item['quantity']

    return render_template('cart.html', items=products, total=total)


@bp.route('/cart/add/<int:product_id>', methods=['POST'])
def add_to_cart(product_id):
    """Add product to cart"""
    quantity = int(request.form.get('quantity', 1))

    cart = session.get('cart', [])

    # Check if product already in cart
    found = False
    for item in cart:
        if item['product_id'] == product_id:
            item['quantity'] += quantity
            found = True
            break

    if not found:
        cart.append({'product_id': product_id, 'quantity': quantity})

    session['cart'] = cart
    return redirect(url_for('main.cart'))


@bp.route('/cart/remove/<int:product_id>', methods=['POST'])
def remove_from_cart(product_id):
    """Remove product from cart"""
    cart = session.get('cart', [])
    cart = [item for item in cart if item['product_id'] != product_id]
    session['cart'] = cart
    return redirect(url_for('main.cart'))


@bp.route('/checkout', methods=['GET'])
def checkout():
    """Checkout page - display order summary"""
    if 'user' not in session:
        return redirect(url_for('main.login'))

    # GET - show checkout page
    cart_items = session.get('cart', [])
    products = []
    total = 0.0

    for item in cart_items:
        product_row = execute_one(
            'SELECT id, name, description, price FROM products WHERE id = %s',
            (item['product_id'],)
        )
        if product_row:
            product = Product.from_db_row(product_row)
            products.append({
                'product': product,
                'quantity': item['quantity'],
                'subtotal': product.price * item['quantity']
            })
            total += product.price * item['quantity']

    return render_template('checkout.html', items=products, total=total)


@bp.route('/checkout/place-order', methods=['POST'])
def place_order():
    """Process checkout and create order"""
    if 'user' not in session:
        return redirect(url_for('main.login'))

    cart = session.get('cart', [])

    if not cart:
        return redirect(url_for('main.index'))

    # Calculate total
    total = 0.0
    for item in cart:
        product_row = execute_one(
            'SELECT price FROM products WHERE id = %s',
            (item['product_id'],)
        )
        if product_row:
            total += float(product_row[0]) * item['quantity']

    # Create order
    with get_db_connection() as conn:
        with get_db_cursor(conn) as cursor:
            # Insert order
            cursor.execute(
                'INSERT INTO orders (order_date, total_amount, status) VALUES (NOW(), %s, %s) RETURNING id',
                (total, 'pending')
            )
            order_id = cursor.fetchone()[0]

            # Insert order items
            for item in cart:
                product_row = execute_one(
                    'SELECT price FROM products WHERE id = %s',
                    (item['product_id'],)
                )
                if product_row:
                    cursor.execute(
                        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (%s, %s, %s, %s)',
                        (order_id, item['product_id'], item['quantity'], float(product_row[0]))
                    )

                    # Update inventory
                    cursor.execute(
                        'UPDATE inventory SET quantity = quantity - %s, last_updated = NOW() WHERE product_id = %s',
                        (item['quantity'], item['product_id'])
                    )

    # Clear cart
    session['cart'] = []

    return redirect(url_for('main.order_confirmation', order_id=order_id))


@bp.route('/order/<int:order_id>')
def order_confirmation(order_id):
    """Order confirmation page"""
    order_row = execute_one(
        'SELECT id, order_date, total_amount, status FROM orders WHERE id = %s',
        (order_id,)
    )

    if not order_row:
        return redirect(url_for('main.index'))

    order = Order.from_db_row(order_row)

    # Get order items
    items_rows = execute_query(
        '''SELECT oi.id, oi.order_id, oi.product_id, oi.quantity, oi.price, p.name
           FROM order_items oi
           JOIN products p ON oi.product_id = p.id
           WHERE oi.order_id = %s''',
        (order_id,)
    )

    items = []
    for row in items_rows:
        items.append({
            'product_name': row[5],
            'quantity': row[3],
            'price': float(row[4]),
            'subtotal': float(row[4]) * row[3]
        })

    return render_template('order_confirmation.html', order=order, items=items)


@bp.route('/health')
def health():
    """Health check endpoint - verifies database connectivity and schema"""
    checks = {
        'status': 'healthy',
        'database': 'unknown',
        'schema': 'unknown',
        'tables': []
    }

    try:
        # Test 1: Database connection
        execute_one('SELECT 1')
        checks['database'] = 'connected'

        # Test 2: Verify critical tables exist
        required_tables = ['products', 'orders', 'order_items', 'inventory']
        existing_tables = []

        for table in required_tables:
            try:
                # Check if table exists and has at least the expected structure
                execute_one(f"SELECT COUNT(*) FROM {table} LIMIT 1")
                existing_tables.append(table)
            except Exception:
                # Table doesn't exist
                pass

        checks['tables'] = existing_tables

        # Determine overall schema status
        if len(existing_tables) == len(required_tables):
            checks['schema'] = 'complete'
        elif len(existing_tables) > 0:
            checks['schema'] = 'partial'
            checks['status'] = 'degraded'
            checks['missing_tables'] = list(set(required_tables) - set(existing_tables))
        else:
            checks['schema'] = 'missing'
            checks['status'] = 'unhealthy'
            checks['error'] = 'Database schema not initialized'

        # Return appropriate status code
        if checks['status'] == 'healthy':
            return jsonify(checks), 200
        elif checks['status'] == 'degraded':
            return jsonify(checks), 503  # Service Unavailable
        else:
            return jsonify(checks), 500  # Internal Server Error

    except Exception as e:
        checks['status'] = 'unhealthy'
        checks['database'] = 'disconnected'
        checks['error'] = str(e)
        return jsonify(checks), 500


@bp.route('/version')
def version():
    """Version info endpoint for deployment verification"""
    version_info = {
        'application': 'bagel-store',
        'version': os.getenv('APP_VERSION', '1.0.0'),
        'environment': os.getenv('FLASK_ENV', 'production'),
        'demo_id': os.getenv('DEMO_ID', 'local')
    }
    return jsonify(version_info), 200
