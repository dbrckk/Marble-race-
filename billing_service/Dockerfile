FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080 MARBLE_DB_PATH=/data/purchases.sqlite3
WORKDIR /app
COPY billing_service/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --requirement requirements.txt \
    && useradd --system --uid 10001 marble \
    && mkdir -p /data && chown marble:marble /data
COPY billing_service ./billing_service
USER marble
EXPOSE 8080
CMD ["python", "-m", "billing_service.app"]
