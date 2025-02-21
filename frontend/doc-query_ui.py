import os
import streamlit as st
import requests

# ------------------------------------------------------------------------------
# Persistent Header and Subheading
# ------------------------------------------------------------------------------
st.title("Ask My Doc")
st.subheader("Unlock insights in your documents with LLM and RAG")

# ------------------------------------------------------------------------------
# Backend URL
# ------------------------------------------------------------------------------
backend_host = os.getenv('BACKEND_HOST')
backend_port = os.getenv('BACKEND_PORT')

if backend_host is None or backend_port is None:
    backend_url = "http://doc_backend:8003"
else:
    backend_url = f"http://{backend_host}:{backend_port}"

# ------------------------------------------------------------------------------
# Initialize Session State
# ------------------------------------------------------------------------------
if "upload_complete" not in st.session_state:
    st.session_state.upload_complete = False

# ------------------------------------------------------------------------------
# File Upload Section (Shown only until files are successfully processed)
# ------------------------------------------------------------------------------
if not st.session_state.upload_complete:
    st.header("Upload Files")
    uploaded_files = st.file_uploader(
        "Choose PDF, Markdown, or Text files", 
        type=["pdf", "md", "txt"], 
        accept_multiple_files=True
    )
    
    if st.button("Upload and Process Files"):
        if uploaded_files:
            files = []
            # Process each uploaded file and set an appropriate MIME type
            for file in uploaded_files:
                file_ext = file.name.split('.')[-1].lower()
                if file_ext == "pdf":
                    mime = "application/pdf"
                elif file_ext == "md":
                    mime = "text/markdown"
                elif file_ext == "txt":
                    mime = "text/plain"
                else:
                    mime = "application/octet-stream"
                files.append(("files", (file.name, file.getvalue(), mime)))
            
            # Send files to the backend
            response = requests.post(f"{backend_url}/upload/", files=files)
            if response.status_code == 200:
                st.success(response.json().get("message", "Files uploaded successfully."))
                st.session_state.upload_complete = True
            else:
                st.error("Failed to upload files.")
        else:
            st.warning("Please upload at least one PDF, Markdown, or text file.")

# ------------------------------------------------------------------------------
# Q&A Section (Shown only after successful file upload)
# ------------------------------------------------------------------------------
if st.session_state.upload_complete:
    st.header("Ask a Question")
    question = st.text_input("Enter your question here:")
    
    if st.button("Get Answer"):
        if question:
            response = requests.post(f"{backend_url}/query/", json={"question": question})
            if response.status_code == 200:
                data = response.json()
                answer = data.get("answer", "No answer found.")
                sources = data.get("sources", "")
                st.write(f"**Answer:** {answer}")
                if sources:
                    st.write(f"**Sources:** {sources}")
            else:
                st.error("Failed to get an answer.")
        else:
            st.warning("Please enter a question.")