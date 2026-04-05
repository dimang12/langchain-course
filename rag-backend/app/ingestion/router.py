import json
import os
from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Query, UploadFile, File, HTTPException

from app.config import settings
from app.ingestion.processor import DocumentProcessor
from app.ingestion.embedder import embed_and_store, delete_source_embeddings

router = APIRouter()


def _sources_path(user_id: str) -> str:
    user_dir = os.path.join(settings.UPLOAD_DIR, user_id)
    os.makedirs(user_dir, exist_ok=True)
    return os.path.join(user_dir, "sources.json")


def _read_sources(user_id: str) -> list:
    path = _sources_path(user_id)
    if not os.path.exists(path):
        return []
    with open(path, "r") as f:
        return json.load(f)


def _write_sources(user_id: str, sources: list) -> None:
    path = _sources_path(user_id)
    with open(path, "w") as f:
        json.dump(sources, f, indent=2)


def _find_source(sources: list, source_id: str) -> dict | None:
    for s in sources:
        if s["id"] == source_id:
            return s
    return None


def _process_document(source_id: str, file_path: str, user_id: str) -> None:
    sources = _read_sources(user_id)
    source = _find_source(sources, source_id)
    if not source:
        return

    source["status"] = "processing"
    _write_sources(user_id, sources)

    try:
        processor = DocumentProcessor()
        chunks = processor.process(file_path, user_id)
        embed_and_store(chunks, user_id)

        sources = _read_sources(user_id)
        source = _find_source(sources, source_id)
        if source:
            source["status"] = "complete"
            source["chunks"] = len(chunks)
            _write_sources(user_id, sources)
    except Exception as e:
        sources = _read_sources(user_id)
        source = _find_source(sources, source_id)
        if source:
            source["status"] = "failed"
            source["error"] = str(e)
            _write_sources(user_id, sources)


@router.post("/upload")
async def upload(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    user_id: str = Query("default"),
):
    user_dir = os.path.join(settings.UPLOAD_DIR, user_id)
    os.makedirs(user_dir, exist_ok=True)

    file_path = os.path.join(user_dir, file.filename)
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    source_id = str(uuid4())
    source_entry = {
        "id": source_id,
        "filename": file.filename,
        "file_path": file_path,
        "status": "pending",
        "uploaded_at": datetime.utcnow().isoformat(),
        "chunks": None,
        "error": None,
    }

    sources = _read_sources(user_id)
    sources.append(source_entry)
    _write_sources(user_id, sources)

    background_tasks.add_task(_process_document, source_id, file_path, user_id)

    return {"job_id": source_id, "filename": file.filename}


@router.get("/sources")
async def list_sources(user_id: str = Query("default")):
    sources = _read_sources(user_id)
    return sources


@router.delete("/sources/{source_id}")
async def delete_source(source_id: str, user_id: str = Query("default")):
    sources = _read_sources(user_id)
    source = _find_source(sources, source_id)
    if not source:
        raise HTTPException(status_code=404, detail="Source not found")

    try:
        delete_source_embeddings(user_id, source["file_path"])
    except Exception:
        pass

    if os.path.exists(source["file_path"]):
        os.remove(source["file_path"])

    sources = [s for s in sources if s["id"] != source_id]
    _write_sources(user_id, sources)

    return {"status": "deleted"}


@router.get("/status/{job_id}")
async def job_status(job_id: str, user_id: str = Query("default")):
    sources = _read_sources(user_id)
    source = _find_source(sources, job_id)
    if not source:
        raise HTTPException(status_code=404, detail="Job not found")
    return source


@router.post("/reindex")
async def reindex(
    background_tasks: BackgroundTasks,
    user_id: str = Query("default"),
):
    sources = _read_sources(user_id)
    completed = [s for s in sources if s["status"] == "complete"]

    for source in completed:
        source["status"] = "pending"
        source["chunks"] = None
        source["error"] = None
        background_tasks.add_task(
            _process_document, source["id"], source["file_path"], user_id
        )

    _write_sources(user_id, sources)

    return {"status": "reindexing", "count": len(completed)}
