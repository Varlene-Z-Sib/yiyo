import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

firebase_path = os.path.join(BASE_DIR, os.getenv("FIREBASE_CREDENTIALS"))

cred = credentials.Certificate(firebase_path)
firebase_admin.initialize_app(cred)

db = firestore.client()