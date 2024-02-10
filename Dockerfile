FROM python:3.10.13-alpine3.19

WORKDIR /app

COPY requirements.txt main.py ./

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    apk add file

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
