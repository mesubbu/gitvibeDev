from __future__ import annotations

import asyncio
import time
import uuid
from typing import Any, Awaitable, Callable

from .security import AuditLogger
from .vault import LocalVault

JobHandler = Callable[[dict[str, Any]], Awaitable[dict[str, Any]]]


class PersistentJobQueue:
    STATE_KEY = "background_job_queue_state"

    def __init__(
        self,
        *,
        vault: LocalVault,
        audit_logger: AuditLogger,
        poll_interval_seconds: float = 1.0,
        retry_base_seconds: int = 2,
    ) -> None:
        self._vault = vault
        self._audit_logger = audit_logger
        self._poll_interval_seconds = max(0.2, poll_interval_seconds)
        self._retry_base_seconds = max(1, retry_base_seconds)
        self._handlers: dict[str, JobHandler] = {}
        self._jobs: dict[str, dict[str, Any]] = {}
        self._queue: list[str] = []
        self._lock = asyncio.Lock()
        self._worker_task: asyncio.Task[None] | None = None
        self._load_state()

    def register_handler(self, job_type: str, handler: JobHandler) -> None:
        self._handlers[job_type] = handler

    def _load_state(self) -> None:
        raw = self._vault.get(self.STATE_KEY, {})
        if not isinstance(raw, dict):
            self._jobs = {}
            self._queue = []
            return
        jobs_raw = raw.get("jobs")
        queue_raw = raw.get("queue")
        self._jobs = jobs_raw if isinstance(jobs_raw, dict) else {}
        self._queue = [item for item in queue_raw if isinstance(item, str)] if isinstance(queue_raw, list) else []
        dirty = False
        for job_id, job in list(self._jobs.items()):
            if not isinstance(job, dict):
                del self._jobs[job_id]
                dirty = True
                continue
            status_value = str(job.get("status", "queued"))
            if status_value == "running":
                job["status"] = "queued"
                status_value = "queued"
                dirty = True
            if status_value == "queued" and job_id not in self._queue:
                self._queue.append(job_id)
                dirty = True
        if dirty:
            self._persist_state()

    def _persist_state(self) -> None:
        self._vault.set(
            self.STATE_KEY,
            {
                "jobs": self._jobs,
                "queue": self._queue,
                "updated_at": int(time.time()),
            },
        )

    @staticmethod
    def _public_job(job: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": job.get("id"),
            "type": job.get("type"),
            "status": job.get("status"),
            "attempts": job.get("attempts"),
            "max_retries": job.get("max_retries"),
            "created_at": job.get("created_at"),
            "updated_at": job.get("updated_at"),
            "last_error": job.get("last_error"),
            "result": job.get("result"),
            "payload": job.get("payload"),
        }

    async def start(self) -> None:
        if self._worker_task is None or self._worker_task.done():
            self._worker_task = asyncio.create_task(self._worker_loop())

    async def stop(self) -> None:
        if self._worker_task is None:
            return
        self._worker_task.cancel()
        try:
            await self._worker_task
        except asyncio.CancelledError:
            pass
        self._worker_task = None

    async def enqueue(
        self,
        *,
        job_type: str,
        payload: dict[str, Any],
        max_retries: int,
    ) -> dict[str, Any]:
        now = int(time.time())
        job_id = str(uuid.uuid4())
        job = {
            "id": job_id,
            "type": job_type,
            "payload": payload,
            "status": "queued",
            "attempts": 0,
            "max_retries": max(0, max_retries),
            "created_at": now,
            "updated_at": now,
            "last_error": None,
            "result": None,
            "run_after": float(now),
        }
        async with self._lock:
            self._jobs[job_id] = job
            self._queue.append(job_id)
            self._persist_state()
        self._audit_logger.security(
            "job_enqueued",
            actor="system",
            details={"job_id": job_id, "job_type": job_type},
        )
        return self._public_job(job)

    async def get_job(self, job_id: str) -> dict[str, Any] | None:
        async with self._lock:
            job = self._jobs.get(job_id)
            if not isinstance(job, dict):
                return None
            return self._public_job(job)

    async def _dequeue_next_job_id(self) -> str | None:
        async with self._lock:
            if not self._queue:
                return None
            now = time.time()
            queue_len = len(self._queue)
            for _ in range(queue_len):
                job_id = self._queue.pop(0)
                job = self._jobs.get(job_id)
                if not isinstance(job, dict) or job.get("status") != "queued":
                    continue
                run_after = float(job.get("run_after", 0.0))
                if run_after > now:
                    self._queue.append(job_id)
                    continue
                job["status"] = "running"
                job["updated_at"] = int(now)
                self._persist_state()
                return job_id
            return None

    async def _mark_completed(self, *, job_id: str, result: dict[str, Any]) -> None:
        async with self._lock:
            job = self._jobs.get(job_id)
            if not isinstance(job, dict):
                return
            job["status"] = "completed"
            job["result"] = result
            job["updated_at"] = int(time.time())
            job["last_error"] = None
            self._persist_state()
        self._audit_logger.security(
            "job_completed",
            actor="system",
            details={"job_id": job_id},
        )

    async def _mark_failed_or_retry(self, *, job_id: str, error_message: str) -> None:
        async with self._lock:
            job = self._jobs.get(job_id)
            if not isinstance(job, dict):
                return
            attempts = int(job.get("attempts", 0)) + 1
            job["attempts"] = attempts
            job["updated_at"] = int(time.time())
            job["last_error"] = error_message
            max_retries = int(job.get("max_retries", 0))
            if attempts <= max_retries:
                retry_delay = self._retry_base_seconds * attempts
                job["status"] = "queued"
                job["run_after"] = time.time() + retry_delay
                self._queue.append(job_id)
                self._persist_state()
                self._audit_logger.security(
                    "job_retry_scheduled",
                    actor="system",
                    details={"job_id": job_id, "attempts": attempts, "retry_delay_seconds": retry_delay},
                )
                return
            job["status"] = "failed"
            self._persist_state()
        self._audit_logger.security(
            "job_failed",
            actor="system",
            details={"job_id": job_id, "attempts": attempts, "error": error_message},
        )

    async def _worker_loop(self) -> None:
        while True:
            job_id = await self._dequeue_next_job_id()
            if job_id is None:
                await asyncio.sleep(self._poll_interval_seconds)
                continue
            async with self._lock:
                job = self._jobs.get(job_id)
                if not isinstance(job, dict):
                    continue
                job_type = str(job.get("type", ""))
                payload = job.get("payload", {})
            handler = self._handlers.get(job_type)
            if handler is None:
                await self._mark_failed_or_retry(
                    job_id=job_id,
                    error_message=f"No handler registered for job type '{job_type}'.",
                )
                continue
            try:
                result = await handler(payload if isinstance(payload, dict) else {})
            except Exception as exc:
                await self._mark_failed_or_retry(job_id=job_id, error_message=str(exc))
                continue
            await self._mark_completed(job_id=job_id, result=result)
