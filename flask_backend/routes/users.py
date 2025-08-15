from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from bson import ObjectId
from extensions import mongo
from models.bank_account import BankAccount
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

users_bp = Blueprint('users', __name__)


@users_bp.route('', methods=['GET'])
@jwt_required()
def list_users():
    """Return a minimal list of users for recipient selection.
    Optional query param `q` filters by name/email substring (case-insensitive).
    Excludes the current user from the list.
    """
    try:
        current_user_id = get_jwt_identity()
        q = (request.args.get('q') or '').strip()

        query = {}
        projection = {'name': 1, 'email': 1}

        if q:
            query['$or'] = [
                {'name': {'$regex': q, '$options': 'i'}},
                {'email': {'$regex': q, '$options': 'i'}},
            ]

        users = list(mongo.db.users.find(query, projection))

        result = []
        for u in users:
            # Skip current user
            try:
                if str(u.get('_id')) == str(current_user_id):
                    continue
            except Exception:
                pass

            result.append({
                '_id': str(u.get('_id')),
                'name': str(u.get('name', '')),
                'email': str(u.get('email', '')),
            })

        return jsonify({'status': 'success', 'data': result})
    except Exception as e:
        logger.error(f"Error listing users: {str(e)}", exc_info=True)
        return jsonify({'status': 'error', 'message': 'Failed to list users'}), 500


@users_bp.route('/<user_id>/accounts', methods=['GET'])
@jwt_required()
def list_user_accounts(user_id: str):
    """Return bank accounts for a specific user to allow transfers."""
    try:
        accounts = BankAccount.get_by_user(user_id) or []

        normalized = []
        for acc in accounts:
            # Ensure ObjectIds are stringified and datetimes serialized
            try:
                acc['_id'] = str(acc.get('_id'))
            except Exception:
                pass
            try:
                acc['user_id'] = str(acc.get('user_id'))
            except Exception:
                pass
            if 'created_at' in acc and acc['created_at']:
                try:
                    acc['created_at'] = acc['created_at'].isoformat()
                except Exception:
                    pass
            if 'updated_at' in acc and acc['updated_at']:
                try:
                    acc['updated_at'] = acc['updated_at'].isoformat()
                except Exception:
                    pass
            normalized.append(acc)

        return jsonify({'status': 'success', 'data': normalized})
    except Exception as e:
        logger.error(f"Error listing accounts for user {user_id}: {str(e)}", exc_info=True)
        return jsonify({'status': 'error', 'message': 'Failed to fetch user accounts'}), 500


