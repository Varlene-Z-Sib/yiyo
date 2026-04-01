import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
firebase_file_name = os.getenv("FIREBASE_CREDENTIALS", "firebase_key.json")
firebase_path = os.path.join(BASE_DIR, firebase_file_name)

print(f"[DEBUG] firebase_path = {firebase_path}")

if not firebase_admin._apps:
    cred = credentials.Certificate(firebase_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()