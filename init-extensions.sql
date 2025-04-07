-- Enable PostGIS extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable pgvector-rs (vector) extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS vector;