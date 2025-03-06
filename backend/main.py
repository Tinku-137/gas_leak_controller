# backend/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from twilio.rest import Client
from sqlalchemy import create_engine, Column, Integer, Float, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import smtplib

# Initialize FastAPI
app = FastAPI()
Base = declarative_base()

# Database setup
engine = create_engine('sqlite:///gas_app.db')
Session = sessionmaker(bind=engine)
session = Session()

# Twilio setup
account_sid = "YOUR_TWILIO_SID"
auth_token = "YOUR_TWILIO_TOKEN"
client = Client(account_sid, auth_token)

# Define the database model
class GasData(Base):
    __tablename__ = "gas_data"
    id = Column(Integer, primary_key=True)
    gas_level = Column(Float)
    gas_leak = Column(Integer)
    timestamp = Column(DateTime, default=datetime.now)

# Pydantic model for request data
class SensorData(BaseModel):
    gas_level: float
    gas_leak: int

# API endpoints
@app.post("/data")
async def receive_data(data: SensorData):
    # Save data to the database
    db_data = GasData(gas_level=data.gas_level, gas_leak=data.gas_leak)
    session.add(db_data)
    session.commit()

    # Check for gas leak
    if data.gas_leak > 500:
        send_alert()
    return {"status": "success"}

def send_alert():
    # Send SMS via Twilio
    client.messages.create(
        body="Gas leak detected!",
        from_="+1234567890",
        to="+0987654321"
    )

@app.get("/control-valve")
async def control_valve(state: bool):
    return {"valve_state": state}