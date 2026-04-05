from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import Chroma

from app.config import settings


def embed_and_store(chunks: list, user_id: str) -> None:
    embedding_fn = OpenAIEmbeddings(
        model="text-embedding-3-small",
        openai_api_key=settings.OPENAI_API_KEY,
    )
    collection_name = f"user_{user_id}"
    Chroma.from_documents(
        documents=chunks,
        embedding=embedding_fn,
        collection_name=collection_name,
        persist_directory=settings.CHROMA_PATH,
    )


def delete_source_embeddings(user_id: str, source_path: str) -> None:
    embedding_fn = OpenAIEmbeddings(
        model="text-embedding-3-small",
        openai_api_key=settings.OPENAI_API_KEY,
    )
    collection_name = f"user_{user_id}"
    store = Chroma(
        collection_name=collection_name,
        embedding_function=embedding_fn,
        persist_directory=settings.CHROMA_PATH,
    )
    results = store.get(where={"source": source_path})
    if results and results["ids"]:
        store.delete(ids=results["ids"])
