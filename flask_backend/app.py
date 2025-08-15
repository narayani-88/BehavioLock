from flask import Flask, jsonify, request, make_response
from flask_cors import CORS, cross_origin
import os
from dotenv import load_dotenv
from bson import ObjectId
import json
from functools import wraps
import logging
from datetime import datetime

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create the Flask application
app = Flask(__name__)

# Configure CORS with more permissive settings for development
CORS(app, 
     resources={
         r"/*": {
             "origins": [
                 "*",  # Allow all origins for development
                 "http://*",
                 "https://*"
             ],
             "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
             "allow_headers": ["*"],
             "expose_headers": ["Content-Length", "X-Foo", "X-Bar"],
             "supports_credentials": True,
             "max_age": 600
         }
     })

# Add CORS headers to all responses
@app.after_request
def after_request(response):
    # Log the request
    logger.debug(f"{request.method} {request.path} - {response.status_code}")
    logger.debug(f"Request Headers: {dict(request.headers)}")
    logger.debug(f"Response Headers: {dict(response.headers)}")
    
    # Add CORS headers
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', '*')
    response.headers.add('Access-Control-Allow-Methods', '*')
    response.headers.add('Access-Control-Allow-Credentials', 'true')
    response.headers.add('Access-Control-Max-Age', '600')
    
    # Handle preflight requests
    if request.method == 'OPTIONS':
        response = make_response()
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', '*')
        response.headers.add('Access-Control-Allow-Methods', '*')
        response.headers.add('Access-Control-Allow-Credentials', 'true')
        response.headers.add('Access-Control-Max-Age', '600')
    
    return response

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key')
app.config['MONGO_URI'] = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/ketstrokebank')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jwt-secret-key')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = 86400  # 24 hours in seconds

# Custom JSON encoder to handle ObjectId
class JSONEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, ObjectId):
            return str(o)
        return json.JSONEncoder.default(self, o)

app.json_encoder = JSONEncoder

def create_app():
    # Initialize extensions
    from extensions import mongo, jwt
    
    # Initialize extensions with app
    mongo.init_app(app)
    jwt.init_app(app)
    
    # Register blueprints
    from routes.routes import auth_bp
    from routes.bank_accounts import bank_accounts_bp
    from routes.transactions import transactions_bp
    from routes.users import users_bp
    
    # Register the blueprints with URL prefixes
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(bank_accounts_bp, url_prefix='/api/accounts')
    app.register_blueprint(transactions_bp, url_prefix='/api/transactions')
    app.register_blueprint(users_bp, url_prefix='/api/users')
    
    # Simple route to test the API
    @app.route('/')
    def index():
        return jsonify({
            'status': 'success',
            'message': 'Welcome to KetStrokeBank API',
            'version': '1.0.0'
        })
    
    return app

if __name__ == '__main__':
    app = create_app()
    app.run(debug=True, host='0.0.0.0', port=5000)
