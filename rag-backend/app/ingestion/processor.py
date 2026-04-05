from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.schema import Document
from unstructured.partition.auto import partition


class DocumentProcessor:
    def __init__(self):
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=800,
            chunk_overlap=150,
            separators=["\n\n", "\n", ". ", " ", ""],
        )

    def process(self, file_path: str, user_id: str) -> list:
        elements = partition(filename=file_path)
        raw_text = "\n\n".join(str(el) for el in elements)
        chunks = self.splitter.create_documents(
            texts=[raw_text],
            metadatas=[{"source": file_path, "user_id": user_id}],
        )
        return chunks
