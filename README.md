# Ask My Doc

**Ask My Doc** is an intuitive Q&A system that lets you upload your documents (PDF, Markdown, or text files) and ask questions in natural language. Powered by a backend microservice that processes your documents into a Retrieval Augmented Generation (RAG) model, Ask My Doc instantly retrieves relevant answers along with their sources.

---

## Features

- **Multi-File Support:** Upload PDFs, Markdown, and plain text files.
- **Dynamic UI:** The upload section disappears after successful processing and the Q&A section appears.
- **Intelligent Querying:** Ask questions about your documents and get precise answers.
- **Easy Setup:** Built with [Streamlit](https://streamlit.io/) for a smooth, web-based interface.
- **Multi-DB Support:** Supports either Weaviate or Redis as the backend vector database.

---

Note: This code uses ChatGPT APIs.

## Prerequisites

* You will need to have an OpenAI API account, with available usage tokens for ChatGPT4.
* You will also need an API Key, which you can create from https://platform.openai.com/account/api-keys
* Python 3.12 with libraries FastAPI, Pydantic (see requirements.txt)
* LangChain 0.3 for Python
# Weaviate or Redis for backend vector database
* Docker on Linux (or Docker Desktop for MacOS)

## Steps to Run As Dockerised Web Service

1. Create an .env file and include the following environment variables:
   ```
   OPENAI_API_KEY=xxxx
   OPENAI_ORGANIZATION_ID=xxxx
   VECTOR_DB=weaviate
   ```
   Set VECTOR_DB=redis if you wish to use Redis.

2. Set up a soft link to link to the right docker compose file to point to the database you wish to use.
   ```
   ln -s docker-compose-weaviate.yml docker-compose.yml
   ```

3. Create the `backend/certs` and `frontend/certs` folders.

4. Build and start up the services.
   ```
   ./rebuild.sh 
   ```

4. Check that the containers are up.
   ```
   docker compose ps -a
   ```

To do limited customisation of the look of the UI, modify the [config.toml](frontend/.streamlit/config.toml) file.

## Using External Redis

If you wish to use an external Redis, you can make use of the `REDIS_HOST` and `REDIS_PORT` in the backend.

This can be done in one of 2 ways:

### Method 1

Set up the environment variables in `backend/.env`:
```
REDIS_HOST=xxx
REDIS_PORT=xxx
```

### Method 2

Update the `docker-compose.yml` file to add in the environment variables to the doc-backend service:
```
   environment:
     REDIS_HOST: xxx
     REDIS_PORT: xxx
```
