import os

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File, Query, Request
from pydantic import BaseModel
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import get_current_user
from app.config import settings
from app.database import get_db
from app.ingestion.processor import DocumentProcessor
from app.ingestion.embedder import embed_and_store
from app.models.user import User
from app.models.workspace import TreeNode

router = APIRouter()


class CreateNodeRequest(BaseModel):
    name: str
    node_type: str
    parent_id: str | None = None
    file_type: str | None = None
    content: str | None = None


class UpdateNodeRequest(BaseModel):
    name: str | None = None
    parent_id: str | None = None
    sort_order: int | None = None
    content: str | None = None


def _node_to_dict(node: TreeNode, children_map: dict) -> dict:
    children = children_map.get(node.id, [])
    return {
        "id": node.id,
        "parent_id": node.parent_id,
        "name": node.name,
        "node_type": node.node_type,
        "file_type": node.file_type,
        "ingestion_status": node.ingestion_status,
        "sort_order": node.sort_order,
        "created_at": node.created_at.isoformat(),
        "updated_at": node.updated_at.isoformat(),
        "children": [_node_to_dict(c, children_map) for c in sorted(children, key=lambda x: (x.sort_order, x.name))],
    }


@router.get("/tree")
async def get_tree(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(TreeNode).where(TreeNode.user_id == user.id)
    )
    all_nodes = result.scalars().all()

    children_map = {}
    roots = []
    for node in all_nodes:
        children_map.setdefault(node.parent_id, []).append(node)

    root_nodes = children_map.get(None, [])
    return [_node_to_dict(n, children_map) for n in sorted(root_nodes, key=lambda x: (x.sort_order, x.name))]


@router.post("/node")
async def create_node(
    request: CreateNodeRequest,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if request.parent_id:
        parent = await db.get(TreeNode, request.parent_id)
        if not parent or parent.user_id != user.id:
            raise HTTPException(status_code=404, detail="Parent folder not found")

    embeddable = {"pdf", "docx", "txt", "md", "html", "csv"}
    should_embed = (
        request.node_type == "file"
        and request.content
        and request.content.strip()
        and request.file_type in embeddable
    )

    node = TreeNode(
        user_id=user.id,
        parent_id=request.parent_id,
        name=request.name,
        node_type=request.node_type,
        file_type=request.file_type,
        content=request.content,
        ingestion_status="pending" if should_embed else None,
    )
    db.add(node)
    await db.commit()
    await db.refresh(node)

    if should_embed:
        background_tasks.add_task(
            _process_content_and_embed, node.id, request.content, request.file_type, user.id, str(settings.DATABASE_URL)
        )

    return {
        "id": node.id,
        "parent_id": node.parent_id,
        "name": node.name,
        "node_type": node.node_type,
        "file_type": node.file_type,
        "ingestion_status": node.ingestion_status,
        "sort_order": node.sort_order,
        "created_at": node.created_at.isoformat(),
        "updated_at": node.updated_at.isoformat(),
        "children": [],
    }


@router.get("/node/{node_id}")
async def get_node(
    node_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    node = await db.get(TreeNode, node_id)
    if not node or node.user_id != user.id:
        raise HTTPException(status_code=404, detail="Node not found")

    content = node.content

    # Read file content if not stored in DB
    if content is None and node.file_path and os.path.exists(node.file_path):
        text_types = {"md", "txt", "csv", "html", "json", "yaml", "yml"}
        if node.file_type in text_types:
            try:
                with open(node.file_path, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                content = "[Could not read this file]"
        else:
            try:
                from unstructured.partition.auto import partition
                elements = partition(filename=node.file_path)
                content = "\n\n".join(str(el) for el in elements)
            except Exception:
                content = "[Could not extract text from this file]"

    return {
        "id": node.id,
        "parent_id": node.parent_id,
        "name": node.name,
        "node_type": node.node_type,
        "file_type": node.file_type,
        "content": content,
        "file_path": node.file_path,
        "ingestion_status": node.ingestion_status,
        "sort_order": node.sort_order,
        "created_at": node.created_at.isoformat(),
        "updated_at": node.updated_at.isoformat(),
    }


@router.put("/node/{node_id}")
async def update_node(
    node_id: str,
    request: UpdateNodeRequest,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    node = await db.get(TreeNode, node_id)
    if not node or node.user_id != user.id:
        raise HTTPException(status_code=404, detail="Node not found")

    if request.name is not None:
        node.name = request.name
    if request.parent_id is not None:
        node.parent_id = request.parent_id
    if request.sort_order is not None:
        node.sort_order = request.sort_order

    content_changed = False
    if request.content is not None:
        node.content = request.content
        content_changed = True

    await db.commit()
    await db.refresh(node)

    # Re-embed if content changed and file type is embeddable
    embeddable = {"pdf", "docx", "txt", "md", "html", "csv"}
    if content_changed and node.node_type == "file" and node.file_type in embeddable and request.content and request.content.strip():
        node.ingestion_status = "pending"
        await db.commit()
        background_tasks.add_task(
            _process_content_and_embed, node.id, request.content, node.file_type, user.id, str(settings.DATABASE_URL)
        )

    return {"status": "updated", "id": node.id}


@router.delete("/node/{node_id}")
async def delete_node(
    node_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    node = await db.get(TreeNode, node_id)
    if not node or node.user_id != user.id:
        raise HTTPException(status_code=404, detail="Node not found")

    await db.delete(node)
    await db.commit()
    return {"status": "deleted"}


def _process_content_and_embed(node_id: str, content: str, file_type: str, user_id: str, db_url: str):
    """Background task: chunk content string and embed into vector DB."""
    import asyncio
    import tempfile
    from sqlalchemy import update
    from sqlalchemy.ext.asyncio import create_async_engine

    async def _run():
        engine = create_async_engine(db_url)
        async with engine.begin() as conn:
            try:
                ext = file_type or "txt"
                with tempfile.NamedTemporaryFile(mode="w", suffix=f".{ext}", delete=False, encoding="utf-8") as tmp:
                    tmp.write(content)
                    tmp_path = tmp.name
                processor = DocumentProcessor()
                chunks = processor.process(tmp_path, user_id)
                if chunks:
                    embed_and_store(chunks, user_id)
                await conn.execute(
                    update(TreeNode).where(TreeNode.id == node_id).values(ingestion_status="complete")
                )
                os.unlink(tmp_path)
            except Exception:
                await conn.execute(
                    update(TreeNode).where(TreeNode.id == node_id).values(ingestion_status="failed")
                )
        await engine.dispose()

    asyncio.run(_run())


def _process_and_embed(node_id: str, file_path: str, user_id: str, db_url: str):
    """Background task: parse, chunk, embed, then update node status."""
    import asyncio
    from sqlalchemy import update
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession as AS
    from sqlalchemy.orm import sessionmaker as sm

    async def _run():
        engine = create_async_engine(db_url)
        async with engine.begin() as conn:
            try:
                processor = DocumentProcessor()
                chunks = processor.process(file_path, user_id)
                embed_and_store(chunks, user_id)
                await conn.execute(
                    update(TreeNode).where(TreeNode.id == node_id).values(ingestion_status="complete")
                )
            except Exception:
                await conn.execute(
                    update(TreeNode).where(TreeNode.id == node_id).values(ingestion_status="failed")
                )
        await engine.dispose()

    asyncio.run(_run())


@router.post("/upload")
async def upload_file(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    parent_id: str | None = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if parent_id:
        parent = await db.get(TreeNode, parent_id)
        if not parent or parent.user_id != user.id:
            raise HTTPException(status_code=404, detail="Parent folder not found")

    user_dir = os.path.join(settings.UPLOAD_DIR, user.id)
    os.makedirs(user_dir, exist_ok=True)
    file_path = os.path.join(user_dir, file.filename)
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else None

    node = TreeNode(
        user_id=user.id,
        parent_id=parent_id,
        name=file.filename,
        node_type="file",
        file_type=ext,
        file_path=file_path,
        ingestion_status="pending",
    )
    db.add(node)
    await db.commit()
    await db.refresh(node)

    embeddable = {"pdf", "docx", "txt", "md", "html", "csv"}
    if ext in embeddable:
        background_tasks.add_task(
            _process_and_embed, node.id, file_path, user.id, str(settings.DATABASE_URL)
        )
    else:
        node.ingestion_status = None
        await db.commit()

    return {
        "id": node.id,
        "name": node.name,
        "node_type": "file",
        "file_type": ext,
        "ingestion_status": node.ingestion_status,
    }


@router.post("/reindex")
async def reindex_workspace(
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Re-embed all workspace files that have content."""
    embeddable = {"pdf", "docx", "txt", "md", "html", "csv"}
    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user.id,
            TreeNode.node_type == "file",
            TreeNode.file_type.in_(embeddable),
        )
    )
    nodes = result.scalars().all()
    count = 0
    for node in nodes:
        content = node.content
        if node.file_path and os.path.exists(node.file_path):
            node.ingestion_status = "pending"
            background_tasks.add_task(
                _process_and_embed, node.id, node.file_path, user.id, str(settings.DATABASE_URL)
            )
            count += 1
        elif content and content.strip():
            node.ingestion_status = "pending"
            background_tasks.add_task(
                _process_content_and_embed, node.id, content, node.file_type, user.id, str(settings.DATABASE_URL)
            )
            count += 1
    await db.commit()
    return {"status": "reindexing", "files_queued": count}


@router.get("/search")
async def search_nodes(
    q: str = Query(""),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not q.strip():
        return []

    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user.id,
            TreeNode.node_type == "file",
            or_(
                TreeNode.name.ilike(f"%{q}%"),
                TreeNode.content.ilike(f"%{q}%"),
            ),
        ).limit(20)
    )
    nodes = result.scalars().all()
    return [
        {
            "id": n.id,
            "name": n.name,
            "file_type": n.file_type,
            "parent_id": n.parent_id,
            "ingestion_status": n.ingestion_status,
        }
        for n in nodes
    ]
