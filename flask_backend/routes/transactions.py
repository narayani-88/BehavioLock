from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from bson import ObjectId
from models.transaction import Transaction
from models.bank_account import BankAccount
from extensions import mongo
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create blueprint
transactions_bp = Blueprint('transactions', __name__)

@transactions_bp.route('', methods=['POST'])
@jwt_required()
def create_transaction():
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['account_id', 'amount', 'transaction_type']
        if not all(field in data for field in required_fields):
            return jsonify({
                'status': 'error',
                'message': 'Missing required fields'
            }), 400
        
        # Convert amount to float
        try:
            amount = float(data['amount'])
            if amount <= 0:
                raise ValueError("Amount must be greater than zero")
        except (ValueError, TypeError):
            return jsonify({
                'status': 'error',
                'message': 'Invalid amount'
            }), 400
        
        # Get the account and verify ownership
        account = BankAccount.get_by_id(data['account_id'])
        if not account or str(account['user_id']) != current_user_id:
            return jsonify({
                'status': 'error',
                'message': 'Account not found or access denied'
            }), 404
        
        # For transfers, verify recipient account
        recipient_account = None
        if data['transaction_type'] == 'transfer':
            if 'recipient_account_id' not in data:
                return jsonify({
                    'status': 'error',
                    'message': 'Recipient account ID is required for transfers'
                }), 400
            
            recipient_account = BankAccount.get_by_id(data['recipient_account_id'])
            if not recipient_account:
                return jsonify({
                    'status': 'error',
                    'message': 'Recipient account not found'
                }), 404
        
        # Check sufficient balance for withdrawals and transfers
        if data['transaction_type'] in ['withdrawal', 'transfer']:
            if amount > float(account['balance']):
                return jsonify({
                    'status': 'error',
                    'message': 'Insufficient funds'
                }), 400
        
        # Create and save the transaction
        transaction = Transaction(
            user_id=current_user_id,
            account_id=data['account_id'],
            amount=amount,
            transaction_type=data['transaction_type'],
            description=data.get('description', ''),
            recipient_account_id=data.get('recipient_account_id'),
            status='pending'  # Will be updated after processing
        )
        
        # Process transaction
        try:
            transactions = mongo.db.transactions
            accounts = mongo.db.bank_accounts
            
            # Start a session for atomic operations
            with mongo.cx.start_session() as session:
                with session.start_transaction():
                    # Save transaction
                    transaction_id = transaction.save()
                    
                    # Update account balances
                    if data['transaction_type'] == 'deposit':
                        accounts.update_one(
                            {'_id': ObjectId(data['account_id'])},
                            {'$inc': {'balance': amount}},
                            session=session
                        )
                    elif data['transaction_type'] == 'withdrawal':
                        accounts.update_one(
                            {'_id': ObjectId(data['account_id'])},
                            {'$inc': {'balance': -amount}},
                            session=session
                        )
                    elif data['transaction_type'] == 'transfer':
                        # Debit from sender
                        accounts.update_one(
                            {'_id': ObjectId(data['account_id'])},
                            {'$inc': {'balance': -amount}},
                            session=session
                        )
                        # Credit to recipient
                        accounts.update_one(
                            {'_id': ObjectId(data['recipient_account_id'])},
                            {'$inc': {'balance': amount}},
                            session=session
                        )
                    
                    # Update transaction status
                    transactions.update_one(
                        {'_id': ObjectId(transaction_id)},
                        {'$set': {'status': 'completed'}},
                        session=session
                    )
                    
                    session.commit_transaction()
            
            # Get updated transaction
            transaction_data = Transaction.get_by_id(transaction_id)
            
            return jsonify({
                'status': 'success',
                'message': 'Transaction completed successfully',
                'data': transaction_data
            }), 201
            
        except Exception as e:
            logger.error(f"Transaction processing error: {str(e)}", exc_info=True)
            # Update transaction status to failed
            try:
                Transaction.update_status(transaction_id, 'failed')
            except:
                pass
            
            return jsonify({
                'status': 'error',
                'message': 'Transaction failed',
                'error': str(e)
            }), 500
            
    except Exception as e:
        logger.error(f"Error creating transaction: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to process transaction',
            'error': str(e)
        }), 500

@transactions_bp.route('', methods=['GET'])
@jwt_required()
def get_transactions():
    try:
        current_user_id = get_jwt_identity()
        account_id = request.args.get('account_id')
        limit = int(request.args.get('limit', '50'))
        skip = int(request.args.get('skip', '0'))
        
        if account_id:
            # Verify account ownership
            account = BankAccount.get_by_id(account_id)
            if not account or str(account['user_id']) != current_user_id:
                return jsonify({
                    'status': 'error',
                    'message': 'Account not found or access denied'
                }), 404
            
            transactions = Transaction.get_by_account(account_id, limit, skip)
        else:
            # Get all transactions for user
            transactions = Transaction.get_by_user(current_user_id, limit, skip)
        
        return jsonify({
            'status': 'success',
            'data': transactions
        })
        
    except Exception as e:
        logger.error(f"Error fetching transactions: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to fetch transactions',
            'error': str(e)
        }), 500

@transactions_bp.route('/<transaction_id>', methods=['GET'])
@jwt_required()
def get_transaction(transaction_id):
    try:
        current_user_id = get_jwt_identity()
        
        # Get transaction
        transaction = Transaction.get_by_id(transaction_id)
        if not transaction:
            return jsonify({
                'status': 'error',
                'message': 'Transaction not found'
            }), 404
        
        # Verify ownership
        if str(transaction['user_id']) != current_user_id:
            return jsonify({
                'status': 'error',
                'message': 'Access denied'
            }), 403
        
        return jsonify({
            'status': 'success',
            'data': transaction
        })
        
    except Exception as e:
        logger.error(f"Error fetching transaction: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to fetch transaction',
            'error': str(e)
        }), 500
