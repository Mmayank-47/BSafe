"""
Auth & Emergency Contact Provisioning Router:
POST /api/v1/auth/register
"""

from fastapi import APIRouter, HTTPException, status
from backend.models import UserRegisterRequest, UserRegisterResponse
from backend.database import db
from backend.services.telephony_service import telephony_service

router = APIRouter(prefix="/api/v1/auth", tags=["Auth & Contacts"])

@router.post("/register", response_model=UserRegisterResponse, status_code=status.HTTP_201_CREATED)
def register_user(request: UserRegisterRequest):
    if len(request.emergency_contacts) < 1 or len(request.emergency_contacts) > 5:
        raise HTTPException(
            status_code=400,
            detail="Mandatory onboarding requirement: Must configure between 1 and 5 emergency contacts."
        )

    # Verify contacts via SMS/WhatsApp OTP simulation
    for contact in request.emergency_contacts:
        contact.otp_code = telephony_service.send_otp_verification(contact.phone_number)
        contact.is_verified = True

    result = db.register_user(request)
    return UserRegisterResponse(**result)
