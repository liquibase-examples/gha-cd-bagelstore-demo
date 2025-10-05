"""
Flask routes for the Bagel Store application.
"""

from flask import Blueprint, render_template, request, redirect, url_for, session, jsonify
from database import execute_query, execute_one, get_db_connection, get_db_cursor
from models import Product, Order, OrderItem

bp = Blueprint('main', __name__)

# Hardcoded user for authentication
DEMO_USER = {'username': 'demo', 'password': 'B@gelSt0re2025!Demo'}


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

        if username == DEMO_USER['username'] and password == DEMO_USER['password']:
            session['user'] = username
            return redirect(url_for('main.index'))
        else:
            return render_template('login.html', error='Invalid credentials')

    return render_template('login.html')


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


@bp.route('/checkout', methods=['GET', 'POST'])
def checkout():
    """Checkout and create order"""
    if 'user' not in session:
        return redirect(url_for('main.login'))

    if request.method == 'POST':
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
    """Health check endpoint"""
    try:
        # Test database connection
        execute_one('SELECT 1')
        return jsonify({'status': 'healthy', 'database': 'connected'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500
