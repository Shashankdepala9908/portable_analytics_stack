import os
import asyncio
from fastapi import FastAPI, Response, status
from sqlalchemy.ext.asyncio import create_async_engine, AsyncEngine

engine: AsyncEngine | None = None

async def _create_engine_with_retries(dsn: str, attempts: int = 30, delay: float = 1.0) -> AsyncEngine:
    last = None
    for _ in range(attempts):
        try:
            eng = create_async_engine(dsn, pool_size=3, max_overflow=2)
            # test a connection immediately
            async with eng.connect() as conn:
                await conn.execute("SELECT 1")
            return eng
        except Exception as e:
            last = e
            await asyncio.sleep(delay)
    raise last

app = FastAPI(title="Portable Analytics")

@app.on_event("startup")
async def on_startup():
    global engine
    dsn = os.getenv("DB_URL")
    if not dsn:
        raise RuntimeError("DB_URL not set")
    engine = await _create_engine_with_retries(dsn)

@app.on_event("shutdown")
async def on_shutdown():
    global engine
    if engine is not None:
        await engine.dispose()
    await asyncio.sleep(0)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/ready")
async def ready(resp: Response):
    global engine
    if engine is None:
        resp.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"ready": False, "reason": "engine-not-initialized"}
    try:
        async with engine.connect() as conn:
            await conn.execute("SELECT 1")
        return {"ready": True}
    except Exception as e:
        resp.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"ready": False, "reason": str(e)}
