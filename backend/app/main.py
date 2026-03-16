from fastapi import FastAPI

app = FastAPI(title="YIYO API")

@app.get("/")
def root():
    return {"message": "YIYO backend running"}