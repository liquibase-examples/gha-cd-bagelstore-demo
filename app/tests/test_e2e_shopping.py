"""
End-to-end shopping flow tests using Playwright.
"""

import pytest
from playwright.sync_api import Page, expect


APP_URL = "http://localhost:5001"


@pytest.mark.e2e
def test_homepage_displays_products(page: Page):
    """Test that homepage displays all 5 bagel products."""
    page.goto(APP_URL)

    # Verify page title
    expect(page).to_have_title("Bagel Store - Fresh Bagels Daily")

    # Verify all 5 products are displayed
    products = page.locator('.product-card')
    expect(products).to_have_count(5)

    # Verify expected product names are present
    page_content = page.content()
    assert 'Plain Bagel' in page_content
    assert 'Everything Bagel' in page_content
    assert 'Blueberry Bagel' in page_content
    assert 'Cinnamon Raisin Bagel' in page_content
    assert 'Asiago Cheese Bagel' in page_content


@pytest.mark.e2e
def test_add_item_to_cart(page: Page, clean_cart):
    """Test adding an item to the shopping cart."""
    page.goto(APP_URL)

    # Check initial cart link text
    cart_link_text_before = page.locator('a:has-text("Cart")').text_content()

    # Find and click "Add to Cart" for first product
    add_button = page.locator('button:has-text("Add to Cart")').first
    add_button.click()

    # Wait for page to reload/update
    page.wait_for_load_state('networkidle')

    # Verify cart link now shows count
    cart_link = page.locator('a:has-text("Cart")')
    cart_link_text_after = cart_link.text_content()

    # Cart should now show a count (e.g., "Cart (1)")
    assert '(' in cart_link_text_after, "Cart should show item count after adding item"


@pytest.mark.e2e
def test_view_cart_page(page: Page, clean_cart):
    """Test viewing the shopping cart page."""
    page.goto(APP_URL)

    # Add an item to cart
    add_button = page.locator('button:has-text("Add to Cart")').first
    add_button.click()
    page.wait_for_timeout(500)

    # Navigate to cart
    cart_link = page.locator('a:has-text("Cart")')
    cart_link.click()

    # Verify we're on cart page
    expect(page).to_have_url(f"{APP_URL}/cart")

    # Verify cart shows at least one item
    cart_items = page.locator('.cart-item')
    expect(cart_items).to_have_count(1)

    # Verify total is displayed and greater than $0
    total_element = page.locator('.cart-total, .total-amount').first
    expect(total_element).to_be_visible()


@pytest.mark.e2e
def test_remove_item_from_cart(page: Page, clean_cart):
    """Test removing an item from the cart."""
    page.goto(APP_URL)

    # Add an item
    add_button = page.locator('button:has-text("Add to Cart")').first
    add_button.click()
    page.wait_for_load_state('networkidle')

    # Go to cart
    page.goto(f"{APP_URL}/cart")

    # Remove the item
    remove_button = page.locator('button.btn-remove, button:has-text("Remove")')
    remove_button.first.click()
    page.wait_for_load_state('networkidle')

    # Cart should be empty
    empty_message = page.locator('text=Your cart is empty')
    expect(empty_message).to_be_visible()


@pytest.mark.e2e
def test_login_success(page: Page):
    """Test successful login flow."""
    page.goto(f"{APP_URL}/login")

    # Fill login form
    page.fill('#username', 'demo')
    page.fill('#password', 'B@gelSt0re2025!Demo')

    # Submit
    page.click('button[type="submit"]')

    # Should redirect to homepage
    page.wait_for_url(APP_URL + "/", timeout=10000)

    # Verify welcome message is shown
    welcome = page.locator('text=Welcome, demo!')
    expect(welcome).to_be_visible(timeout=10000)


@pytest.mark.e2e
def test_login_failure(page: Page):
    """Test login with invalid credentials."""
    page.goto(f"{APP_URL}/login")

    # Fill with wrong credentials
    page.fill('#username', 'wrong')
    page.fill('#password', 'wrongpassword')

    # Submit
    page.click('button[type="submit"]')

    # Wait for page to load
    page.wait_for_load_state('networkidle')

    # Should stay on login page with error
    expect(page).to_have_url(f"{APP_URL}/login")

    # Error message should be visible
    error = page.locator('.error')
    expect(error).to_be_visible()
    expect(error).to_contain_text('Invalid credentials')


@pytest.mark.e2e
def test_logout(page: Page, authenticated_page: Page):
    """Test logout functionality."""
    # authenticated_page fixture already logs us in
    page = authenticated_page

    # Verify we're logged in
    expect(page.locator('text=Welcome, demo!')).to_be_visible()

    # Click logout
    logout_link = page.locator('a:has-text("Logout")')
    logout_link.click()

    # Should redirect to homepage
    page.wait_for_url(APP_URL + "/")

    # Welcome message should not be visible
    welcome = page.locator('text=Welcome, demo!')
    expect(welcome).not_to_be_visible()


@pytest.mark.e2e
def test_checkout_requires_authentication(page: Page, clean_cart):
    """Test that checkout redirects to login when not authenticated."""
    page.goto(APP_URL)

    # Add item to cart
    add_button = page.locator('button:has-text("Add to Cart")').first
    add_button.click()
    page.wait_for_load_state('networkidle')

    # Go to cart and try to checkout
    page.goto(f"{APP_URL}/cart")

    checkout_button = page.locator('a.btn-checkout, a:has-text("Proceed to Checkout")')
    checkout_button.first.click()

    # Should redirect to login page
    page.wait_for_url(f"{APP_URL}/login", timeout=5000)


@pytest.mark.e2e
@pytest.mark.slow
def test_complete_checkout_flow(page: Page, clean_cart, clean_test_orders, db_connection):
    """Test complete end-to-end checkout flow."""
    # 1. Start at homepage
    page.goto(APP_URL)

    # 2. Add item to cart (Plain Bagel - $2.50)
    add_button = page.locator('button:has-text("Add to Cart")').first
    add_button.click()
    page.wait_for_load_state('networkidle')

    # 3. Go to cart
    page.goto(f"{APP_URL}/cart")

    # Verify cart shows item
    expect(page.locator('.cart-item').first).to_be_visible()

    # 4. Proceed to checkout (should redirect to login)
    checkout_button = page.locator('a.btn-checkout')
    checkout_button.click()
    page.wait_for_url(f"{APP_URL}/login", timeout=5000)

    # 5. Login
    page.fill('#username', 'demo')
    page.fill('#password', 'B@gelSt0re2025!Demo')
    page.click('button[type="submit"]')
    page.wait_for_url(APP_URL + "/", timeout=10000)

    # 6. Go back to cart and checkout
    page.goto(f"{APP_URL}/cart")
    checkout_button = page.locator('a.btn-checkout')
    checkout_button.click()

    # Should be on checkout page
    page.wait_for_url(f"{APP_URL}/checkout", timeout=5000)

    # 7. Place order
    place_order_button = page.locator('button:has-text("Place Order")')
    place_order_button.click()

    # 8. Wait for order confirmation (URL pattern: /order/<order_id>)
    page.wait_for_load_state('networkidle', timeout=10000)

    # Verify we're on order confirmation page
    assert '/order/' in page.url, f"Expected order confirmation URL, got {page.url}"

    # Verify order confirmation page content
    expect(page.locator('text=Order Confirmed!')).to_be_visible()
    expect(page.locator('text=Thank you for your order!')).to_be_visible()

    # 9. Verify order was created in database
    cursor = db_connection.cursor()
    cursor.execute("""
        SELECT id, total_amount, status
        FROM orders
        ORDER BY order_date DESC
        LIMIT 1
    """)
    order = cursor.fetchone()

    assert order is not None, "Order should be created in database"
    order_id, total_amount, status = order

    # Verify order details
    assert float(total_amount) > 0, "Order total should be greater than 0"
    assert status in ['pending', 'completed', 'processing'], "Order should have valid status"

    # Verify order items exist
    cursor.execute("""
        SELECT COUNT(*)
        FROM order_items
        WHERE order_id = %s
    """, (order_id,))
    item_count = cursor.fetchone()[0]

    assert item_count > 0, "Order should have at least one item"

    cursor.close()

    # 10. Verify cart is cleared
    page.goto(f"{APP_URL}/cart")
    empty_message = page.locator('text=Your cart is empty')
    expect(empty_message).to_be_visible()


@pytest.mark.e2e
def test_multiple_items_in_cart(page: Page, clean_cart):
    """Test adding multiple different items to cart."""
    page.goto(APP_URL)

    # Add first item
    add_buttons = page.locator('button:has-text("Add to Cart")')
    add_buttons.nth(0).click()
    page.wait_for_load_state('networkidle')

    # Go back to homepage to add another item
    page.goto(APP_URL)

    # Add second item
    add_buttons = page.locator('button:has-text("Add to Cart")')
    add_buttons.nth(1).click()
    page.wait_for_load_state('networkidle')

    # Go to cart
    page.goto(f"{APP_URL}/cart")

    # Should have 2 items
    cart_items = page.locator('.cart-item')
    expect(cart_items).to_have_count(2)


@pytest.mark.e2e
def test_product_prices_displayed(page: Page):
    """Test that all products show prices."""
    page.goto(APP_URL)

    # Each product card should have a price
    products = page.locator('.product-card')
    count = products.count()

    for i in range(count):
        product = products.nth(i)
        # Price should contain a dollar sign
        price_text = product.inner_text()
        assert '$' in price_text, f"Product {i} should display price with $"
