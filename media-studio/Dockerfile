FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 GRADIO_ANALYTICS_ENABLED=False
WORKDIR /app
RUN pip install --no-cache-dir 'gradio>=5,<7' requests pillow
COPY app.py /app/app.py
EXPOSE 7860
CMD ["python", "/app/app.py"]
