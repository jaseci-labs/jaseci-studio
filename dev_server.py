"""Dev server — run Studio standalone for local testing."""

import uvicorn
from fastapi import FastAPI
from jaseci_studio.plugin import mount_studio

app = FastAPI(title="Jaseci Studio (Dev)")
mount_studio(app)


@app.get("/")
async def index():
    return {"message": "Jaseci Studio dev server", "ui": "/_studio"}


if __name__ == "__main__":
    uvicorn.run("dev_server:app", host="0.0.0.0", port=9000, reload=True)
