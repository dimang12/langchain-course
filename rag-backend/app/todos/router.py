"""REST endpoints for the To-Do module: folders, status columns, tasks."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import get_current_user
from app.database import get_db
from app.models.todos import Todo, TodoFolder, TodoStatus
from app.models.user import User

router = APIRouter()


# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DEFAULT_STATUSES = [
    {"name": "To Do", "color": "#8D89A0", "sort_order": 0},
    {"name": "In Progress", "color": "#7C5CFF", "sort_order": 1},
    {"name": "Done", "color": "#5CD4A8", "sort_order": 2},
]


# ---------------------------------------------------------------------------
# Serializers
# ---------------------------------------------------------------------------
def _folder_to_dict(f: TodoFolder) -> dict:
    return {
        "id": f.id,
        "parent_id": f.parent_id,
        "name": f.name,
        "sort_order": f.sort_order,
        "created_at": f.created_at.isoformat(),
        "updated_at": f.updated_at.isoformat(),
    }


def _status_to_dict(s: TodoStatus) -> dict:
    return {
        "id": s.id,
        "folder_id": s.folder_id,
        "name": s.name,
        "color": s.color,
        "sort_order": s.sort_order,
    }


def _todo_to_dict(t: Todo) -> dict:
    return {
        "id": t.id,
        "folder_id": t.folder_id,
        "status_id": t.status_id,
        "title": t.title,
        "description": t.description,
        "priority": t.priority,
        "due_date": t.due_date.isoformat() if t.due_date else None,
        "tags": t.tags or [],
        "sort_order": t.sort_order,
        "goal_id": t.goal_id,
        "estimated_minutes": t.estimated_minutes,
        "is_today_priority": bool(t.is_today_priority),
        "created_at": t.created_at.isoformat(),
        "updated_at": t.updated_at.isoformat(),
        "completed_at": t.completed_at.isoformat() if t.completed_at else None,
    }


# ---------------------------------------------------------------------------
# Folders
# ---------------------------------------------------------------------------
class FolderCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    parent_id: str | None = None


class FolderUpdateRequest(BaseModel):
    name: str | None = None
    parent_id: str | None = None
    sort_order: int | None = None


@router.get("/folders")
async def list_folders(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(TodoFolder)
        .where(TodoFolder.user_id == user.id)
        .order_by(TodoFolder.sort_order, TodoFolder.name)
    )
    folders = result.scalars().all()
    return [_folder_to_dict(f) for f in folders]


@router.post("/folders")
async def create_folder(
    request: FolderCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if request.parent_id:
        parent = await db.get(TodoFolder, request.parent_id)
        if parent is None or parent.user_id != user.id:
            raise HTTPException(status_code=404, detail="Parent folder not found")

    folder = TodoFolder(
        user_id=user.id,
        parent_id=request.parent_id,
        name=request.name.strip(),
    )
    db.add(folder)
    await db.flush()

    # Seed default status columns for new folder
    for s in DEFAULT_STATUSES:
        db.add(TodoStatus(folder_id=folder.id, **s))

    await db.commit()
    await db.refresh(folder)
    return _folder_to_dict(folder)


@router.patch("/folders/{folder_id}")
async def update_folder(
    folder_id: str,
    request: FolderUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    folder = await db.get(TodoFolder, folder_id)
    if folder is None or folder.user_id != user.id:
        raise HTTPException(status_code=404, detail="Folder not found")

    if request.name is not None:
        folder.name = request.name.strip()
    if request.parent_id is not None:
        if request.parent_id == folder_id:
            raise HTTPException(status_code=400, detail="Folder cannot be its own parent")
        folder.parent_id = request.parent_id or None
    if request.sort_order is not None:
        folder.sort_order = request.sort_order

    await db.commit()
    await db.refresh(folder)
    return _folder_to_dict(folder)


@router.delete("/folders/{folder_id}")
async def delete_folder(
    folder_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    folder = await db.get(TodoFolder, folder_id)
    if folder is None or folder.user_id != user.id:
        raise HTTPException(status_code=404, detail="Folder not found")
    await db.delete(folder)
    await db.commit()
    return {"status": "deleted"}


# ---------------------------------------------------------------------------
# Statuses (per folder, customizable columns)
# ---------------------------------------------------------------------------
class StatusCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    color: str = "#7C5CFF"
    sort_order: int = 0


class StatusUpdateRequest(BaseModel):
    name: str | None = None
    color: str | None = None
    sort_order: int | None = None


@router.get("/folders/{folder_id}/statuses")
async def list_statuses(
    folder_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    folder = await db.get(TodoFolder, folder_id)
    if folder is None or folder.user_id != user.id:
        raise HTTPException(status_code=404, detail="Folder not found")
    result = await db.execute(
        select(TodoStatus)
        .where(TodoStatus.folder_id == folder_id)
        .order_by(TodoStatus.sort_order)
    )
    return [_status_to_dict(s) for s in result.scalars().all()]


@router.post("/folders/{folder_id}/statuses")
async def create_status(
    folder_id: str,
    request: StatusCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    folder = await db.get(TodoFolder, folder_id)
    if folder is None or folder.user_id != user.id:
        raise HTTPException(status_code=404, detail="Folder not found")
    status = TodoStatus(
        folder_id=folder_id,
        name=request.name.strip(),
        color=request.color,
        sort_order=request.sort_order,
    )
    db.add(status)
    await db.commit()
    await db.refresh(status)
    return _status_to_dict(status)


@router.patch("/statuses/{status_id}")
async def update_status(
    status_id: str,
    request: StatusUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    status = await db.get(TodoStatus, status_id)
    if status is None:
        raise HTTPException(status_code=404, detail="Status not found")
    folder = await db.get(TodoFolder, status.folder_id)
    if folder is None or folder.user_id != user.id:
        raise HTTPException(status_code=404, detail="Status not found")

    if request.name is not None:
        status.name = request.name.strip()
    if request.color is not None:
        status.color = request.color
    if request.sort_order is not None:
        status.sort_order = request.sort_order

    await db.commit()
    await db.refresh(status)
    return _status_to_dict(status)


@router.delete("/statuses/{status_id}")
async def delete_status(
    status_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    status = await db.get(TodoStatus, status_id)
    if status is None:
        raise HTTPException(status_code=404, detail="Status not found")
    folder = await db.get(TodoFolder, status.folder_id)
    if folder is None or folder.user_id != user.id:
        raise HTTPException(status_code=404, detail="Status not found")

    # Move tasks in this status to null (caller should reassign)
    await db.execute(
        select(Todo).where(Todo.status_id == status_id)
    )

    await db.delete(status)
    await db.commit()
    return {"status": "deleted"}


# ---------------------------------------------------------------------------
# Todos
# ---------------------------------------------------------------------------
class TodoCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=500)
    folder_id: str | None = None
    status_id: str | None = None
    description: str | None = None
    priority: str = "medium"
    due_date: str | None = None
    tags: list[str] | None = None
    goal_id: str | None = None
    estimated_minutes: int | None = None


class TodoUpdateRequest(BaseModel):
    title: str | None = None
    folder_id: str | None = None
    status_id: str | None = None
    description: str | None = None
    priority: str | None = None
    due_date: str | None = None
    tags: list[str] | None = None
    sort_order: int | None = None
    completed: bool | None = None
    goal_id: str | None = None
    estimated_minutes: int | None = None
    is_today_priority: bool | None = None


@router.get("/todos")
async def list_todos(
    folder_id: str | None = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Todo).where(Todo.user_id == user.id)
    if folder_id is not None:
        stmt = stmt.where(Todo.folder_id == folder_id)
    stmt = stmt.order_by(Todo.sort_order, Todo.created_at.desc())
    result = await db.execute(stmt)
    return [_todo_to_dict(t) for t in result.scalars().all()]


@router.post("/todos")
async def create_todo(
    request: TodoCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if request.folder_id:
        folder = await db.get(TodoFolder, request.folder_id)
        if folder is None or folder.user_id != user.id:
            raise HTTPException(status_code=404, detail="Folder not found")

    # Default to first status of folder if not provided
    status_id = request.status_id
    if status_id is None and request.folder_id is not None:
        result = await db.execute(
            select(TodoStatus)
            .where(TodoStatus.folder_id == request.folder_id)
            .order_by(TodoStatus.sort_order)
            .limit(1)
        )
        first_status = result.scalar_one_or_none()
        if first_status is not None:
            status_id = first_status.id

    due = None
    if request.due_date:
        try:
            due = datetime.fromisoformat(request.due_date)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid due_date")

    todo = Todo(
        user_id=user.id,
        folder_id=request.folder_id,
        status_id=status_id,
        title=request.title.strip(),
        description=request.description,
        priority=request.priority,
        due_date=due,
        tags=request.tags,
        goal_id=request.goal_id,
        estimated_minutes=request.estimated_minutes,
    )
    db.add(todo)
    await db.commit()
    await db.refresh(todo)
    return _todo_to_dict(todo)


@router.patch("/todos/{todo_id}")
async def update_todo(
    todo_id: str,
    request: TodoUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    todo = await db.get(Todo, todo_id)
    if todo is None or todo.user_id != user.id:
        raise HTTPException(status_code=404, detail="Todo not found")

    if request.title is not None:
        todo.title = request.title.strip()
    if request.folder_id is not None:
        todo.folder_id = request.folder_id or None
    if request.status_id is not None:
        todo.status_id = request.status_id or None
    if request.description is not None:
        todo.description = request.description
    if request.priority is not None:
        todo.priority = request.priority
    if request.due_date is not None:
        if request.due_date == "":
            todo.due_date = None
        else:
            try:
                todo.due_date = datetime.fromisoformat(request.due_date)
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid due_date")
    if request.tags is not None:
        todo.tags = request.tags
    if request.sort_order is not None:
        todo.sort_order = request.sort_order
    if request.completed is not None:
        todo.completed_at = datetime.utcnow() if request.completed else None
    if request.goal_id is not None:
        todo.goal_id = request.goal_id or None
    if request.estimated_minutes is not None:
        todo.estimated_minutes = request.estimated_minutes
    if request.is_today_priority is not None:
        todo.is_today_priority = request.is_today_priority

    await db.commit()
    await db.refresh(todo)
    return _todo_to_dict(todo)


@router.delete("/todos/{todo_id}")
async def delete_todo(
    todo_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    todo = await db.get(Todo, todo_id)
    if todo is None or todo.user_id != user.id:
        raise HTTPException(status_code=404, detail="Todo not found")
    await db.delete(todo)
    await db.commit()
    return {"status": "deleted"}
