from datetime import datetime
from bson import ObjectId
from extensions import mongo

class Transaction:
    def __init__(self, user_id, account_id, amount, transaction_type, 
                 description="", recipient_account_id=None, status="pending"):
        self.user_id = user_id
        self.account_id = account_id
        self.amount = float(amount)
        self.transaction_type = transaction_type  # 'deposit', 'withdrawal', 'transfer', 'payment'
        self.description = description
        self.recipient_account_id = recipient_account_id
        self.status = status  # 'pending', 'completed', 'failed', 'cancelled'
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
        self.reference = f"TXN{int(datetime.utcnow().timestamp())}"

    def to_dict(self):
        return {
            'user_id': self.user_id,
            'account_id': self.account_id,
            'amount': self.amount,
            'transaction_type': self.transaction_type,
            'description': self.description,
            'recipient_account_id': self.recipient_account_id,
            'status': self.status,
            'reference': self.reference,
            'created_at': self.created_at,
            'updated_at': self.updated_at
        }

    @classmethod
    def from_dict(cls, data):
        transaction = cls(
            user_id=data['user_id'],
            account_id=data['account_id'],
            amount=data['amount'],
            transaction_type=data['transaction_type'],
            description=data.get('description', ''),
            recipient_account_id=data.get('recipient_account_id'),
            status=data.get('status', 'pending')
        )
        if 'created_at' in data:
            transaction.created_at = data['created_at']
        if 'updated_at' in data:
            transaction.updated_at = data['updated_at']
        if 'reference' in data:
            transaction.reference = data['reference']
        return transaction

    def save(self):
        transactions = mongo.db.transactions
        result = transactions.insert_one(self.to_dict())
        return str(result.inserted_id)

    @staticmethod
    def get_by_id(transaction_id):
        try:
            transaction = mongo.db.transactions.find_one({
                '_id': ObjectId(transaction_id)
            })
            if transaction:
                transaction['_id'] = str(transaction['_id'])
                transaction['account_id'] = str(transaction['account_id'])
                if 'recipient_account_id' in transaction and transaction['recipient_account_id']:
                    transaction['recipient_account_id'] = str(transaction['recipient_account_id'])
            return transaction
        except Exception as e:
            print(f"Error getting transaction by ID: {e}")
            return None

    @staticmethod
    def get_by_user(user_id, limit=50, skip=0):
        try:
            transactions = list(mongo.db.transactions
                .find({'user_id': user_id})
                .sort('created_at', -1)
                .skip(skip)
                .limit(limit))
            
            # Convert ObjectId to string for JSON serialization
            for t in transactions:
                t['_id'] = str(t['_id'])
                t['account_id'] = str(t['account_id'])
                if 'recipient_account_id' in t and t['recipient_account_id']:
                    t['recipient_account_id'] = str(t['recipient_account_id'])
            
            return transactions
        except Exception as e:
            print(f"Error getting transactions by user: {e}")
            return []

    @staticmethod
    def get_by_account(account_id, limit=50, skip=0):
        try:
            transactions = list(mongo.db.transactions
                .find({'account_id': account_id})
                .sort('created_at', -1)
                .skip(skip)
                .limit(limit))
            
            # Convert ObjectId to string for JSON serialization
            for t in transactions:
                t['_id'] = str(t['_id'])
                t['account_id'] = str(t['account_id'])
                if 'recipient_account_id' in t and t['recipient_account_id']:
                    t['recipient_account_id'] = str(t['recipient_account_id'])
            
            return transactions
        except Exception as e:
            print(f"Error getting transactions by account: {e}")
            return []

    @staticmethod
    def update_status(transaction_id, status):
        try:
            mongo.db.transactions.update_one(
                {'_id': ObjectId(transaction_id)},
                {'$set': {
                    'status': status,
                    'updated_at': datetime.utcnow()
                }}
            )
            return True
        except Exception as e:
            print(f"Error updating transaction status: {e}")
            return False
