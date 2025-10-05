"""
Main Flask application for Bagel Store.
"""

import os
from flask import Flask
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


def create_app():
    """Application factory"""
    app = Flask(__name__)

    # Configuration
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
    app.config['SESSION_COOKIE_HTTPONLY'] = True

    # Register blueprints
    from routes import bp
    app.register_blueprint(bp)

    return app


if __name__ == '__main__':
    app = create_app()
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=os.environ.get('FLASK_ENV') == 'development')
