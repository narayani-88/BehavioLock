from datetime import datetime
from bson import ObjectId
from extensions import mongo

class BankAccount:
    def __init__(self, user_id, account_number, account_holder_name, bank_name, 
                 ifsc_code, account_type, balance=0.0, is_primary=False):
        self.user_id = user_id
        self.account_number = account_number
        self.account_holder_name = account_holder_name
        self.bank_name = bank_name
        self.ifsc_code = ifsc_code
        self.account_type = account_type  # 'savings', 'checking', etc.
        self.balance = float(balance)
        self.is_primary = bool(is_primary)
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()

    def to_dict(self):
        # Ensure all fields have consistent types
        from bson import ObjectId
        
        # Handle user_id type consistency
        user_id = self.user_id
        if user_id and not isinstance(user_id, ObjectId):
            try:
                user_id = ObjectId(str(user_id))
            except:
                pass  # Keep as is if conversion fails
        
        # Ensure balance is float
        try:
            balance = float(self.balance)
        except (TypeError, ValueError):
            balance = 0.0
            
        # Ensure boolean fields are properly cast
        is_primary = bool(self.is_primary)
        
        return {
            'user_id': user_id,
            'account_number': str(self.account_number) if self.account_number is not None else '',
            'account_holder_name': str(self.account_holder_name) if self.account_holder_name is not None else '',
            'bank_name': str(self.bank_name) if self.bank_name is not None else '',
            'ifsc_code': str(self.ifsc_code) if self.ifsc_code is not None else '',
            'account_type': str(self.account_type) if self.account_type is not None else 'savings',
            'balance': balance,
            'is_primary': is_primary,
            'created_at': self.created_at if hasattr(self, 'created_at') and self.created_at else datetime.utcnow(),
            'updated_at': self.updated_at if hasattr(self, 'updated_at') and self.updated_at else datetime.utcnow()
        }

    @classmethod
    def from_dict(cls, data):
        return cls(
            user_id=data['user_id'],
            account_number=data['account_number'],
            account_holder_name=data['account_holder_name'],
            bank_name=data['bank_name'],
            ifsc_code=data['ifsc_code'],
            account_type=data['account_type'],
            balance=data.get('balance', 0.0),
            is_primary=data.get('is_primary', False)
        )

    def save(self):
        accounts = mongo.db.bank_accounts
        
        # Ensure user_id is consistently stored as ObjectId
        from bson import ObjectId
        if not isinstance(self.user_id, ObjectId):
            try:
                self.user_id = ObjectId(str(self.user_id))
            except:
                pass  # Keep as string if conversion fails
        
        # If this is the first account for the user, make it primary
        user_query = {'user_id': self.user_id}
        if accounts.count_documents(user_query) == 0:
            self.is_primary = True
        
        # If this account is marked as primary, unset primary from other accounts
        if self.is_primary:
            accounts.update_many(
                user_query,
                {'$set': {'is_primary': False, 'updated_at': datetime.utcnow()}}
            )
        
        # Add timestamps
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
        
        # Insert the account
        account_data = self.to_dict()
        result = accounts.insert_one(account_data)
        return str(result.inserted_id)

    @staticmethod
    def get_by_user(user_id):
        accounts = mongo.db.bank_accounts
        try:
            # First try to find with ObjectId if user_id is a valid ObjectId string
            from bson.errors import InvalidId
            try:
                return list(accounts.find({'user_id': ObjectId(user_id)}))
            except (InvalidId, TypeError):
                # If not a valid ObjectId, try with string comparison
                return list(accounts.find({'user_id': str(user_id)}))
        except Exception as e:
            print(f"Error in get_by_user: {str(e)}")
            return []

    @staticmethod
    def get_by_id(account_id):
        accounts = mongo.db.bank_accounts
        return accounts.find_one({'_id': ObjectId(account_id)})

    @staticmethod
    def update(account_id, update_data):
        accounts = mongo.db.bank_accounts
        update_data['updated_at'] = datetime.utcnow()
        
        # If making this account primary, unset primary from others
        if update_data.get('is_primary') is True:
            account = accounts.find_one({'_id': ObjectId(account_id)})
            if account:
                accounts.update_many(
                    {'user_id': account['user_id'], '_id': {'$ne': ObjectId(account_id)}, 'is_primary': True},
                    {'$set': {'is_primary': False}}
                )
                
        return accounts.update_one(
            {'_id': ObjectId(account_id)},
            {'$set': update_data}
        )

    @staticmethod
    def delete(account_id):
        accounts = mongo.db.bank_accounts
        return accounts.delete_one({'_id': ObjectId(account_id)})
