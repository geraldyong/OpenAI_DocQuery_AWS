FROM python:3.12-slim

# Create app user.
# Use this for non-alpine.
#RUN useradd --user-group --system --no-log-init --create-home appusr
# Use this for alpine.
RUN addgroup --system apps --gid 1000 && adduser --system appuser --uid 1000 --gid 1000

# Copy files.
WORKDIR /app
COPY --chown=appuser:apps *.py  /app
COPY --chown=appuser:apps .streamlit  /app/.streamlit
COPY --chown=appuser:apps requirements.txt /app
COPY --chown=appuser:apps certs /app/certs

RUN pip install --no-cache-dir -r requirements.txt && \
    rm -f /app/requirements.txt

EXPOSE 3003

CMD ["streamlit", "run", "doc-query_ui.py", "--server.port", "3003", "&&", "wait"]
