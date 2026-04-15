# STAGE 1: Build Stage
FROM python:3.12-slim AS Builder

WORKDIR /app
# Install system level dependencies required for MYSQL
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-libmysqlclient-dev \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements.txt
COPY requirements.txt .

# Install requirements.txt 
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# STAGE 2: Runtime Stage
FROM python:3.12-slim

WORKDIR /app

# Copy the libraries from the builder stage
COPY --from=Builder /install /usr/local

# Install runtime-only library for MySQL
RUN apt-get update && apt-get install -y --no-install-recommends default-libmysqlclient-dev && rm -rf /var/lib/apt/lists/*

# Copy application code
COPY . .

# Create application user
RUN useradd -m flaskuser
USER flaskuser

EXPOSE 5000

# Execute the code
CMD ["python", "app.py"]