from flask_pymongo import PyMongo
from flask_jwt_extended import JWTManager
from bson import ObjectId
import ssl
import certifi
import json

# Initialize extensions
mongo = PyMongo()
jwt = JWTManager()

# Custom JSON encoder to handle ObjectId
class JSONEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, ObjectId):
            return str(o)
        return json.JSONEncoder.default(self, o)

# Initialize the app with extensions
def init_app(app):
    # Initialize MongoDB
    try:
        print("Initializing MongoDB connection...")
        
        # Get MongoDB URI from config
        mongo_uri = app.config.get('MONGO_URI')
        print(f"MongoDB URI: {mongo_uri}")
        
        # Set up SSL context
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        
        # Initialize MongoDB with connection options
        mongo.init_app(
            app,
            connectTimeoutMS=30000,
            socketTimeoutMS=None,
            connect=False,
            maxPoolsize=1,
            ssl=True,
            ssl_cert_reqs=ssl.CERT_NONE
        )
        
        # Test the connection
        with app.app_context():
            mongo.db.command('ping')
            print("MongoDB connection successful!")
            
    except Exception as e:
        print(f"MongoDB connection error: {str(e)}")
        raise
    
    # Initialize JWT
    jwt.init_app(app)
    
    # Set custom JSON encoder
    app.json_encoder = JSONEncoder
    
    return app
