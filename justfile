# SpaceNote PostgreSQL Development Commands

# Database configuration
DB_NAME := "spacenote_postgresql"
DB_HOST := "localhost"
DB_PORT := "5432"
# Uses default PostgreSQL user (from environment or current system user)

# Initialize database (create DB and apply schema)
init:
    @echo "Creating database '{{DB_NAME}}'..."
    @psql -h {{DB_HOST}} -p {{DB_PORT}} -tc "SELECT 1 FROM pg_database WHERE datname = '{{DB_NAME}}'" | grep -q 1 || \
        psql -h {{DB_HOST}} -p {{DB_PORT}} -c "CREATE DATABASE {{DB_NAME}}"
    @echo "Applying schema from sql/init.sql..."
    @psql -h {{DB_HOST}} -p {{DB_PORT}} -d {{DB_NAME}} -f sql/init.sql
    @echo "✓ Database initialized successfully"

# Reinitialize database (drop and recreate)
reinit:
    @echo "Dropping database '{{DB_NAME}}'..."
    @psql -h {{DB_HOST}} -p {{DB_PORT}} -c "DROP DATABASE IF EXISTS {{DB_NAME}}"
    @echo "Reinitializing database..."
    @just init

# Check database status and show tables
db-status:
    @echo "Checking connection to '{{DB_NAME}}'..."
    @psql -h {{DB_HOST}} -p {{DB_PORT}} -d {{DB_NAME}} -c "\conninfo"
    @echo ""
    @echo "Tables:"
    @psql -h {{DB_HOST}} -p {{DB_PORT}} -d {{DB_NAME}} -c "\dt"
    @echo ""
    @echo "Table sizes:"
    @psql -h {{DB_HOST}} -p {{DB_PORT}} -d {{DB_NAME}} -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
