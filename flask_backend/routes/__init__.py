# This file makes the routes directory a Python package
# Import blueprints here to make them available when importing from routes
from .bank_accounts import bank_accounts_bp
from .routes import auth_bp  # Import from the routes module in the same package

__all__ = ['bank_accounts_bp', 'auth_bp']
