"""Tests for the image proxy endpoint with CORS and caching."""
import pytest
from httpx import AsyncClient, ASGITransport
import respx
import httpx
from app.main import app


@pytest.mark.asyncio
async def test_image_proxy_rejected_host():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Host not allowed
        res = await client.get("/image?url=https://evil-site.com/image.jpg")
        assert res.status_code == 400
        assert "not allowed" in res.json()["detail"]


@pytest.mark.asyncio
@respx.mock
async def test_image_proxy_allowed_host():
    fake_url = "https://i.ytimg.com/vi/test_id/hqdefault.jpg"
    respx.get(fake_url).mock(
        return_value=httpx.Response(200, content=b"fake-image-bytes", headers={"Content-Type": "image/jpeg"})
    )

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get(f"/image?url={fake_url}")
        assert res.status_code == 200
        assert res.content == b"fake-image-bytes"
        assert res.headers["Access-Control-Allow-Origin"] == "*"
        assert "max-age" in res.headers["Cache-Control"]
