-- Enable PostGIS extension if it doesn't exist (safe check)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable vchord extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS vchord;

-- Add vchord schema to search path for the current user (role)
-- This ensures functions are found without schema qualification
-- The entrypoint script runs this as the user defined by POSTGRES_USER
ALTER ROLE current_user SET search_path TO "$user", public, vchord;
