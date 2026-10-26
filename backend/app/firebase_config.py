
import os

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

firebase_file_name = os.getenv("FIREBASE_CREDENTIALS")
local_firebase_path = os.path.join(
    BASE_DIR,
    "firebase_key.json",
)

if not firebase_admin._apps:
    if firebase_file_name:
        firebase_path = firebase_file_name

        if not os.path.isabs(firebase_path):
            firebase_path = os.path.join(
                BASE_DIR,
                firebase_path,
            )

        cred = credentials.Certificate(firebase_path)
        firebase_admin.initialize_app(cred)

    elif os.getenv("K_SERVICE"):
        # Cloud Run: use Application Default Credentials.
        firebase_admin.initialize_app()

    elif os.path.isfile(local_firebase_path):
        # Local development: preserve the existing key-file setup.
        cred = credentials.Certificate(local_firebase_path)
        firebase_admin.initialize_app(cred)

    else:
        # Fall back to Application Default Credentials.
        firebase_admin.initialize_app()

db = firestore.client()
