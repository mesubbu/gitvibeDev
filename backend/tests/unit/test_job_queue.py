from __future__ import annotations

import asyncio
import time

import pytest

from app.job_queue import PersistentJobQueue
from app.security import AuditLogger
from app.vault import LocalVault


pytestmark = [pytest.mark.unit, pytest.mark.asyncio]


async def test_queue_completes_job(tmp_path):
    vault = LocalVault(file_path=str(tmp_path / "vault.enc"), master_key="queue-key")
    logger = AuditLogger(file_path=str(tmp_path / "audit.log"))
    queue = PersistentJobQueue(
        vault=vault,
        audit_logger=logger,
        poll_interval_seconds=0.2,
        retry_base_seconds=1,
    )

    async def handler(payload):
        return {"status": "ok", "echo": payload.get("value")}

    queue.register_handler("echo", handler)
    await queue.start()
    try:
        queued = await queue.enqueue(job_type="echo", payload={"value": 3}, max_retries=0)
        deadline = time.time() + 3
        while time.time() < deadline:
            current = await queue.get_job(queued["id"])
            if current and current.get("status") == "completed":
                assert current["result"]["echo"] == 3
                break
            await asyncio.sleep(0.05)
        else:
            raise AssertionError("Job did not complete in time")
    finally:
        await queue.stop()


async def test_queue_retry_state_transition(tmp_path):
    vault = LocalVault(file_path=str(tmp_path / "vault.enc"), master_key="queue-key")
    logger = AuditLogger(file_path=str(tmp_path / "audit.log"))
    queue = PersistentJobQueue(
        vault=vault,
        audit_logger=logger,
        poll_interval_seconds=0.2,
        retry_base_seconds=1,
    )
    queued = await queue.enqueue(job_type="missing", payload={}, max_retries=1)
    await queue._mark_failed_or_retry(job_id=queued["id"], error_message="boom")
    current = await queue.get_job(queued["id"])

    assert current is not None
    assert current["status"] == "queued"
    assert current["attempts"] == 1
