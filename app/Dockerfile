FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /app

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies (much faster than pip)
RUN uv sync --frozen --no-dev

# Copy application code
COPY src/ ./src/

# Set environment
ENV PATH="/app/.venv/bin:$PATH"
ENV FLASK_ENV=production

EXPOSE 5000

CMD ["uv", "run", "python", "src/app.py"]
