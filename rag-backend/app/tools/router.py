from fastapi import APIRouter
from app.tools.registry import TOOLS_INFO

router = APIRouter()


@router.get("/")
async def list_tools():
    return TOOLS_INFO
