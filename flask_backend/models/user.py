from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
from bson import ObjectId
from extensions import mongo

class User:
    collection_name = 'users'
    
    def __init__(self, name, email, password, phone_number=None, created_at=None, last_login=None, _id=None):
        self._id = _id or ObjectId()
        self.name = name
        self.email = email
        self.password_hash = generate_password_hash(password) if password else None
        self.phone_number = phone_number
        self.created_at = created_at or datetime.utcnow()
        self.last_login = last_login
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
        
    def check_password(self, password):
        if not self.password_hash:
            return False
        return check_password_hash(self.password_hash, password)
    
    def save(self):
        user_data = self.to_dict()
        if self._id:
            # Update existing user
            result = mongo.db[self.collection_name].update_one(
                {'_id': self._id},
                {'$set': user_data}
            )
            return str(self._id)
        else:
            # Insert new user
            user_data.pop('_id', None)  # Remove _id for insert
            result = mongo.db[self.collection_name].insert_one(user_data)
            self._id = result.inserted_id
            return str(self._id)
    
    @classmethod
    def get_by_email(cls, email):
        user_data = mongo.db[cls.collection_name].find_one({'email': email})
        if user_data:
            return cls.from_dict(user_data)
        return None
    
    @classmethod
    def get_by_id(cls, user_id):
        try:
            user_data = mongo.db[cls.collection_name].find_one({'_id': ObjectId(user_id)})
            if user_data:
                return cls.from_dict(user_data)
            return None
        except:
            return None
    
    def to_dict(self):
        return {
            '_id': self._id,
            'name': self.name,
            'email': self.email,
            'password_hash': self.password_hash,
            'phone_number': self.phone_number,
            'created_at': self.created_at,
            'last_login': self.last_login
        }
    
    @classmethod
    def from_dict(cls, data):
        user = cls(
            name=data['name'],
            email=data['email'],
            password='',  # Password will be set from hash
            phone_number=data.get('phone_number'),
            created_at=data.get('created_at'),
            last_login=data.get('last_login'),
            _id=data.get('_id')
        )
        if 'password_hash' in data:
            user.password_hash = data['password_hash']
        return user
