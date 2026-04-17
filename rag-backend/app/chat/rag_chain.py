from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferWindowMemory
from app.config import settings


class RAGChain:
    def __init__(self, user_id: str):
        self.embeddings = OpenAIEmbeddings(
            model="text-embedding-3-small",
            openai_api_key=settings.OPENAI_API_KEY,
        )
        self.vectorstore = Chroma(
            collection_name=f"user_{user_id}",
            embedding_function=self.embeddings,
            persist_directory=settings.CHROMA_PATH,
        )
        self.llm = ChatOpenAI(
            model="gpt-4o-mini",
            max_tokens=4096,
            temperature=0.3,
            openai_api_key=settings.OPENAI_API_KEY,
        )
        self.memory = ConversationBufferWindowMemory(
            k=10,
            memory_key="chat_history",
            return_messages=True,
            output_key="answer",
        )
        self.chain = ConversationalRetrievalChain.from_llm(
            llm=self.llm,
            retriever=self.vectorstore.as_retriever(
                search_kwargs={"k": 5}
            ),
            memory=self.memory,
            return_source_documents=True,
            output_key="answer",
        )

    async def query(self, question: str) -> dict:
        result = await self.chain.ainvoke(
            {"question": question}
        )
        sources = list(dict.fromkeys(
            doc.metadata.get("source", "unknown")
            for doc in result["source_documents"]
        ))
        return {
            "answer": result["answer"],
            "sources": sources,
        }

    async def stream(self, question: str):
        retriever = self.vectorstore.as_retriever(search_kwargs={"k": 5})
        docs = await retriever.ainvoke(question)
        context = "\n\n".join(doc.page_content for doc in docs)

        from app.chat.prompts import QA_PROMPT_TEMPLATE
        prompt = QA_PROMPT_TEMPLATE.format(
            context=context,
            chat_history="",
            question=question,
        )

        async for chunk in self.llm.astream(prompt):
            if chunk.content:
                yield chunk.content
