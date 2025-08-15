from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import create_access_token, get_jwt_identity, jwt_required
from datetime import datetime, timedelta
from bson import ObjectId
from werkzeug.security import generate_password_hash, check_password_hash
from extensions import mongo
from models.user import User
import json

# Create blueprint
auth_bp = Blueprint('auth', __name__)

def user_exists(email):
    return mongo.db.users.find_one({'email': email}) is not None

def create_user(user_data):
    print("\n=== Creating New User ===")
    print(f"1. Raw user data: {user_data}")
    
    try:
        # Hash the password
        print("2. Hashing password...")
        hashed_password = generate_password_hash(user_data['password'])
        print("3. Password hashed successfully")
        
        # Prepare user document
        user = {
            'name': user_data['name'],
            'email': user_data['email'].lower().strip(),  # Normalize email
            'password': hashed_password,
            'phone_number': user_data.get('phone_number', '').strip(),
            'created_at': datetime.utcnow(),
            'last_login': None,
            'is_active': True
        }
        
        print("4. User document prepared:", user)
        
        # Get database and collection
        db = mongo.db
        users_collection = db.users
        print(f"5. Using database: {db.name}")
        print(f"6. Using collection: {users_collection.name}")
        
        # Check collection stats (for debugging)
        try:
            stats = db.command('collstats', 'users')
            print(f"7. Collection stats: {stats}")
        except Exception as stats_err:
            print(f"7. Could not get collection stats: {str(stats_err)}")
        
        # Insert the user
        print("8. Inserting user into database...")
        result = users_collection.insert_one(user)
        print(f"9. Insert result - inserted_id: {result.inserted_id}")
        
        if not result.inserted_id:
            raise Exception("No inserted_id returned from database")
        
        # Verify the user was inserted
        print("10. Verifying user insertion...")
        inserted_user = users_collection.find_one({'_id': result.inserted_id})
        
        if not inserted_user:
            raise Exception("Failed to verify user insertion - user not found after insert")
            
        print(f"11. User verified in database. _id: {inserted_user['_id']}")
        
        # Convert ObjectId to string for JSON serialization
        inserted_user['_id'] = str(inserted_user['_id'])
        
        # Remove sensitive data before returning
        inserted_user.pop('password', None)
        
        print("12. User creation completed successfully")
        return inserted_user
        
    except Exception as e:
        print("\n!!! ERROR IN CREATE_USER !!!")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {str(e)}")
        import traceback
        traceback.print_exc()
        raise

def verify_user(email, password):
    user = mongo.db.users.find_one({'email': email})
    if user and check_password_hash(user['password'], password):
        user['_id'] = str(user['_id'])
        return user
    return None

@auth_bp.route('/register', methods=['POST'])
def register():
    try:
        print("\n=== Registration Endpoint Called ===")
        data = request.get_json()
        print("1. Received registration data:", data)
        
        if not data:
            print("Error: No JSON data received")
            return jsonify({'message': 'No data provided'}), 400
        
        # Validate required fields
        required_fields = ['name', 'email', 'password', 'phone_number']
        missing_fields = [field for field in required_fields if field not in data]
        
        if missing_fields:
            print(f"2. Missing required fields: {missing_fields}")
            return jsonify({
                'message': 'Missing required fields',
                'missing_fields': missing_fields
            }), 400
        
        print("3. All required fields present")
        
        # Check if user already exists
        print(f"4. Checking if user with email {data['email']} exists...")
        existing_user = mongo.db.users.find_one({'email': data['email']})
        
        if existing_user:
            print(f"5. User with email {data['email']} already exists")
            return jsonify({
                'message': 'User already exists with this email',
                'email': data['email']
            }), 400
        
        print("6. No existing user found, creating new user...")
        
        # Create new user
        try:
            user = create_user(data)
            print("7. User created successfully:", user)
            
            # Generate access token
            access_token = create_access_token(identity=str(user['_id']))
            print("8. Access token generated")
            
            # Remove password before sending response
            user.pop('password', None)
            
            response = {
                'message': 'User registered successfully',
                'access_token': access_token,
                'user': user
            }
            print("9. Sending success response")
            return jsonify(response), 201
            
        except Exception as create_error:
            print(f"ERROR in user creation: {str(create_error)}")
            print(f"Error type: {type(create_error).__name__}")
            import traceback
            traceback.print_exc()
            return jsonify({
                'message': 'Failed to create user',
                'error': str(create_error)
            }), 500
        
    except Exception as e:
        print("\n!!! UNHANDLED ERROR IN REGISTER ENDPOINT !!!")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return jsonify({
            'message': 'An unexpected error occurred',
            'error': str(e)
        }), 500

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    print("\n=== LOGIN ENDPOINT CALLED ===")
    print(f"1. Received login data: {data}")
    
    # Validate required fields
    if 'email' not in data or 'password' not in data:
        print("2. Missing email or password in request data")
        return jsonify({'message': 'Email and password are required'}), 400
    
    # Verify user credentials
    user = verify_user(data['email'], data['password'])
    print(f"3. User found: {user}")
    
    if not user:
        print("4. Invalid credentials: user not found or password mismatch")
        return jsonify({'message': 'Invalid email or password'}), 401
    
    # Update last login
    mongo.db.users.update_one(
        {'_id': ObjectId(user['_id'])},
        {'$set': {'last_login': datetime.utcnow()}}
    )
    
    # Generate access token
    access_token = create_access_token(identity=user['_id'])
    
    # Remove password before sending response
    user.pop('password', None)
    
    print("5. Login successful, sending response with access_token")
    return jsonify({
        'access_token': access_token,
        'user': user
    })

@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_me():
    current_user_id = get_jwt_identity()
    
    try:
        user = mongo.db.users.find_one({'_id': ObjectId(current_user_id)})
        
        if not user:
            return jsonify({'message': 'User not found'}), 404
            
        # Convert ObjectId to string for JSON serialization
        user['_id'] = str(user['_id'])
        
        # Remove password before sending response
        user.pop('password', None)
        
        return jsonify(user)
    except Exception as e:
        return jsonify({'message': str(e)}), 500
