import os
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.schema import Document


# File types we can read directly without unstructured
TEXT_READABLE = {"md", "txt", "csv", "html", "json", "yaml", "yml"}


class DocumentProcessor:
    def __init__(self):
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=800,
            chunk_overlap=150,
            separators=["\n\n", "\n", ". ", " ", ""],
        )

    def process(self, file_path: str, user_id: str) -> list:
        ext = file_path.rsplit(".", 1)[-1].lower() if "." in file_path else ""

        if ext in TEXT_READABLE:
            with open(file_path, "r", encoding="utf-8") as f:
                raw_text = f.read()
        else:
            try:
                from unstructured.partition.auto import partition
                elements = partition(filename=file_path)
                raw_text = "\n\n".join(str(el) for el in elements)
            except ImportError:
                # Fallback: try reading as text
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    raw_text = f.read()

        if not raw_text.strip():
            return []

        chunks = self.splitter.create_documents(
            texts=[raw_text],
            metadatas=[{"source": file_path, "user_id": user_id}],
        )
        return chunks
