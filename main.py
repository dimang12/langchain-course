from dotenv import load_dotenv
from langchain_openai import ChatOpenAI


load_dotenv()


def main():
    llm = ChatOpenAI(model="gpt-3.5-turbo")
    print(llm.invoke("Hello! How are you today?"))


if __name__ == "__main__":
    main()
