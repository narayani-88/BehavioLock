from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from bson import ObjectId
from models.bank_account import BankAccount
from extensions import mongo
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create blueprint
bank_accounts_bp = Blueprint('bank_accounts', __name__)

@bank_accounts_bp.route('', methods=['POST'])
@jwt_required()
def create_account():
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['account_number', 'account_holder_name', 'bank_name', 'ifsc_code', 'account_type']
        if not all(field in data for field in required_fields):
            return jsonify({
                'status': 'error',
                'message': 'Missing required fields'
            }), 400
        
        # Create new account
        account = BankAccount(
            user_id=current_user_id,
            account_number=data['account_number'],
            account_holder_name=data['account_holder_name'],
            bank_name=data['bank_name'],
            ifsc_code=data['ifsc_code'],
            account_type=data['account_type'],
            balance=float(data.get('balance', 0.0)),
            is_primary=bool(data.get('is_primary', False))
        )
        
        # Save to database
        account_id = account.save()
        
        return jsonify({
            'status': 'success',
            'message': 'Account created successfully',
            'account_id': account_id
        }), 201
        
    except Exception as e:
        logger.error(f"Error creating account: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to create account',
            'error': str(e)
        }), 500

@bank_accounts_bp.route('', methods=['GET'])
@jwt_required()
def get_accounts():
    try:
        current_user_id = get_jwt_identity()
        logger.info(f'Fetching accounts for user: {current_user_id}')
        
        # Get accounts from database
        accounts = BankAccount.get_by_user(current_user_id)
        logger.info(f'Retrieved {len(accounts)} accounts from database')
        
        # Prepare response data
        response_data = []
        for account in accounts:
            # Create a copy to avoid modifying the original
            account_data = account.copy()
            
            # Convert ObjectId to string
            account_data['_id'] = str(account_data.get('_id', ''))
            account_data['user_id'] = str(account_data.get('user_id', ''))
            
            # Convert datetime to ISO format
            if 'created_at' in account_data and account_data['created_at']:
                account_data['created_at'] = account_data['created_at'].isoformat()
            if 'updated_at' in account_data and account_data['updated_at']:
                account_data['updated_at'] = account_data['updated_at'].isoformat()
                
            logger.info(f'Account data: {account_data}')
            response_data.append(account_data)
        
        response = {
            'status': 'success',
            'data': response_data
        }
        
        logger.info(f'Returning response: {response}')
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error fetching accounts: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to fetch accounts',
            'error': str(e)
        }), 500

@bank_accounts_bp.route('/<account_id>', methods=['GET'])
@jwt_required()
def get_account(account_id):
    try:
        current_user_id = get_jwt_identity()
        account = BankAccount.get_by_id(account_id)
        
        if not account:
            return jsonify({
                'status': 'error',
                'message': 'Account not found'
            }), 404
            
        # Check if the account belongs to the current user
        if str(account['user_id']) != current_user_id:
            return jsonify({
                'status': 'error',
                'message': 'Unauthorized access to account'
            }), 403
            
        # Convert ObjectId to string for JSON serialization
        account['_id'] = str(account['_id'])
        account['user_id'] = str(account['user_id'])
        # Convert datetime to ISO format
        account['created_at'] = account['created_at'].isoformat() if 'created_at' in account else None
        account['updated_at'] = account['updated_at'].isoformat() if 'updated_at' in account else None
        
        return jsonify({
            'status': 'success',
            'data': account
        })
        
    except Exception as e:
        logger.error(f"Error fetching account: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to fetch account',
            'error': str(e)
        }), 500

@bank_accounts_bp.route('/<account_id>', methods=['PUT'])
@jwt_required()
def update_account(account_id):
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        # Check if account exists and belongs to user
        account = BankAccount.get_by_id(account_id)
        if not account or str(account['user_id']) != current_user_id:
            return jsonify({
                'status': 'error',
                'message': 'Account not found or unauthorized'
            }), 404
        
        # Update account
        update_data = {
            'account_holder_name': data.get('account_holder_name', account['account_holder_name']),
            'bank_name': data.get('bank_name', account['bank_name']),
            'ifsc_code': data.get('ifsc_code', account['ifsc_code']),
            'account_type': data.get('account_type', account['account_type']),
            'balance': float(data.get('balance', account['balance'])),
            'is_primary': data.get('is_primary', account.get('is_primary', False))
        }
        
        # Update in database
        result = BankAccount.update(account_id, update_data)
        
        if result.modified_count == 0:
            return jsonify({
                'status': 'error',
                'message': 'Failed to update account'
            }), 500
            
        return jsonify({
            'status': 'success',
            'message': 'Account updated successfully'
        })
        
    except Exception as e:
        logger.error(f"Error updating account: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to update account',
            'error': str(e)
        }), 500

@bank_accounts_bp.route('/<account_id>', methods=['DELETE'])
@jwt_required()
def delete_account(account_id):
    try:
        current_user_id = get_jwt_identity()
        
        # Check if account exists and belongs to user
        account = BankAccount.get_by_id(account_id)
        if not account or str(account['user_id']) != current_user_id:
            return jsonify({
                'status': 'error',
                'message': 'Account not found or unauthorized'
            }), 404
            
        # Don't allow deleting the only account
        user_accounts_count = mongo.db.bank_accounts.count_documents({
            'user_id': ObjectId(current_user_id)
        })
        
        if user_accounts_count <= 1:
            return jsonify({
                'status': 'error',
                'message': 'Cannot delete the only account. Please add another account first.'
            }), 400
            
        # If deleting primary account, set another account as primary
        if account.get('is_primary'):
            another_account = mongo.db.bank_accounts.find_one({
                'user_id': ObjectId(current_user_id),
                '_id': {'$ne': ObjectId(account_id)}
            })
            
            if another_account:
                mongo.db.bank_accounts.update_one(
                    {'_id': another_account['_id']},
                    {'$set': {'is_primary': True}}
                )
        
        # Delete the account
        result = BankAccount.delete(account_id)
        
        if result.deleted_count == 0:
            return jsonify({
                'status': 'error',
                'message': 'Failed to delete account'
            }), 500
            
        return jsonify({
            'status': 'success',
            'message': 'Account deleted successfully'
        })
        
    except Exception as e:
        logger.error(f"Error deleting account: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': 'Failed to delete account',
            'error': str(e)
        }), 500
