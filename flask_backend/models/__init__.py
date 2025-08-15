# This makes the models directory a Python package
from .bank_account import BankAccount
from .user import User  # We'll create this file next

__all__ = ['BankAccount', 'User']
