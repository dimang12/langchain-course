from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter()


@router.post("/register")
async def register():
    return JSONResponse(status_code=501, content={"message": "not implemented"})


@router.post("/login")
async def login():
    return JSONResponse(status_code=501, content={"message": "not implemented"})


@router.post("/refresh")
async def refresh():
    return JSONResponse(status_code=501, content={"message": "not implemented"})
