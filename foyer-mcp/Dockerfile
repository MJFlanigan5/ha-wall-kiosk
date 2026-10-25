FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends chromium fonts-liberation \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
ENV FOYER_MCP_TRANSPORT=http FOYER_CHROME_PATH=/usr/bin/chromium
EXPOSE 8092
CMD ["python", "main.py"]
