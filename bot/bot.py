import os
import asyncio
from dotenv import load_dotenv
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes
from telegram.error import Conflict
import asyncpg
from datetime import datetime, timezone

load_dotenv()

# Database connection pool
_db_pool = None


async def get_db_pool():
    """Get or create database connection pool"""
    global _db_pool
    if _db_pool is None:
        database_url = os.getenv('DATABASE_URL')
        if not database_url:
            raise ValueError("DATABASE_URL environment variable is not set")
        
        # For local development on Windows, handle SSL certificate issues
        # In production (Railway), SSL will work fine
        import ssl
        
        try:
            # Try with SSL first (required for Neon)
            ssl_context = ssl.create_default_context()
            _db_pool = await asyncpg.create_pool(
                database_url,
                ssl=ssl_context
            )
        except Exception as e:
            # If SSL fails on Windows, try with relaxed SSL settings
            print(f"SSL connection failed with default context: {e}")
            print("Trying with relaxed SSL settings for local development...")
            ssl_context = ssl.create_default_context()
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE
            try:
                _db_pool = await asyncpg.create_pool(
                    database_url,
                    ssl=ssl_context
                )
            except Exception as e2:
                print(f"SSL connection failed even with relaxed settings: {e2}")
                raise
    return _db_pool


async def init_db():
    """Initialize database - create users table if it doesn't exist"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                telegram_id BIGINT UNIQUE NOT NULL,
                username VARCHAR(255),
                first_name VARCHAR(255),
                last_name VARCHAR(255),
                language_code VARCHAR(10),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        # Create index on telegram_id for faster lookups
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id)
        """)
        print("Database initialized: users table created/verified")


async def save_user(update: Update):
    """Save or update user in database"""
    try:
        pool = await get_db_pool()
        user = update.effective_user
        
        async with pool.acquire() as conn:
            # Use PostgreSQL's CURRENT_TIMESTAMP instead of Python datetime
            # to avoid timezone awareness issues
            await conn.execute("""
                INSERT INTO users (telegram_id, username, first_name, last_name, language_code, last_active_at)
                VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
                ON CONFLICT (telegram_id) 
                DO UPDATE SET 
                    username = EXCLUDED.username,
                    first_name = EXCLUDED.first_name,
                    last_name = EXCLUDED.last_name,
                    language_code = EXCLUDED.language_code,
                    last_active_at = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
            """, 
                user.id,
                user.username,
                user.first_name,
                user.last_name,
                user.language_code
            )
    except Exception as e:
        print(f"Error saving user to database: {e}")


async def hello(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    # Save user to database
    await save_user(update)
    await update.message.reply_text(f'Hello {update.effective_user.first_name}')


async def post_init(app):
    """Delete webhook and initialize database on startup"""
    # Delete webhook before starting polling to avoid conflicts
    try:
        await app.bot.delete_webhook(drop_pending_updates=True)
        print("Webhook deleted (if it existed)")
        # Small delay to ensure webhook deletion is processed
        await asyncio.sleep(1)
    except Exception as e:
        print(f"Note: Could not delete webhook: {e}")
    
    # Initialize database
    try:
        await init_db()
        print("Database connection established")
    except Exception as e:
        print(f"Warning: Could not initialize database: {e}")
        print("Bot will continue but user data won't be saved")


async def shutdown():
    """Close database pool on shutdown"""
    global _db_pool
    if _db_pool:
        await _db_pool.close()
        print("Database connection closed")


def main():
    token = os.getenv('token')
    if not token:
        raise ValueError("Environment variable 'token' is not set")
    
    app = ApplicationBuilder().token(token).post_init(post_init).post_shutdown(shutdown).build()
    app.add_handler(CommandHandler("start", hello))
    
    print("Bot starting...")
    try:
        app.run_polling(drop_pending_updates=True, allowed_updates=Update.ALL_TYPES)
    except Conflict as e:
        print("Error: Another bot instance is already running or webhook conflict exists.")
        print("This usually resolves automatically. If it persists, check for other running instances.")
        print(f"Details: {e}")
        # Don't re-raise, just exit gracefully
        return
    except KeyboardInterrupt:
        print("\nBot stopped by user")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
