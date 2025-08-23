import os
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI

# Load environment variables from .env file
load_dotenv()

def example_openai_usage():
    # Get API key from environment variable
    api_key = os.getenv("OPENAI_API_KEY")
    
    if not api_key:
        print("Error: OPENAI_API_KEY not found in environment variables")
        print("Please create a .env file with your API key")
        return
    
    # Initialize the OpenAI chat model
    llm = ChatOpenAI(
        api_key=api_key,
        model="gpt-3.5-turbo"  # or use os.getenv("OPENAI_MODEL")
    )
    
    # Example usage
    response = llm.invoke("Hello! How are you today?")
    print(response.content)

if __name__ == "__main__":
    example_openai_usage()
