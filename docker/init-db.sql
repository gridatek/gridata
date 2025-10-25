-- Initialize databases for Gridata components

-- Create databases
CREATE DATABASE IF NOT EXISTS datahub;
CREATE DATABASE IF NOT EXISTS metastore;

-- Create users (if needed)
-- Already using default 'gridata' user

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE airflow TO gridata;
GRANT ALL PRIVILEGES ON DATABASE datahub TO gridata;
GRANT ALL PRIVILEGES ON DATABASE metastore TO gridata;
