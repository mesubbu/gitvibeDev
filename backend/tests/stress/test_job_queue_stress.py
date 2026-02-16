from __future__ import annotations

import asyncio
import time

import pytest

from app.job_queue import PersistentJobQueue
from app.security import AuditLogger
from app.vault import LocalVault


pytestmark = [pytest.mark.stress, pytest.mark.asyncio]


async def test_job_queue_handles_burst_load(tmp_path):
    vault = LocalVault(file_path=str(tmp_path / "stress-vault.enc"), master_key="stress-key")
    logger = AuditLogger(file_path=str(tmp_path / "stress-audit.log"))
    queue = PersistentJobQueue(
        vault=vault,
        audit_logger=logger,
        poll_interval_seconds=0.2,
        retry_base_seconds=1,
    )

    async def worker(payload):
        await asyncio.sleep(0)
        return {"status": "ok", "id": payload["index"]}

    queue.register_handler("burst", worker)
    await queue.start()
    try:
        jobs = [
            await queue.enqueue(job_type="burst", payload={"index": i}, max_retries=0)
            for i in range(120)
        ]

        deadline = time.time() + 12
        while time.time() < deadline:
            completed = 0
            for item in jobs:
                state = await queue.get_job(item["id"])
                if state and state.get("status") == "completed":
                    completed += 1
            if completed == len(jobs):
                break
            await asyncio.sleep(0.05)
        else:
            raise AssertionError("Not all stress jobs completed")

        assert completed == len(jobs)
    finally:
        await queue.stop()
