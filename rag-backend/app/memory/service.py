"""Memory Layer — persistent knowledge about the user, their org, and learned facts.

Architecture (MemGPT-inspired):
- Core Memory    : UserProfile + OrgContext, always injected into system prompt (~1KB)
- Archival Memory: MemoryFact rows in Postgres + per-user ChromaDB collection for semantic recall
- Episodic Memory: Compressed conversation summaries stored as MemoryFacts with source='episodic'
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.identity import MemoryFact, OrgContext, UserProfile


class MemoryLayer:
    """Per-user memory layer. Instantiate once per request."""

    def __init__(self, user_id: str, db: AsyncSession):
        self.user_id = user_id
        self.db = db
        self._embeddings: OpenAIEmbeddings | None = None
        self._vectorstore: Chroma | None = None

    # ------------------------------------------------------------------
    # Lazy init for Chroma (expensive; only create if archival ops used)
    # ------------------------------------------------------------------
    @property
    def vectorstore(self) -> Chroma:
        if self._vectorstore is None:
            self._embeddings = OpenAIEmbeddings(
                model="text-embedding-3-small",
                openai_api_key=settings.OPENAI_API_KEY,
            )
            self._vectorstore = Chroma(
                collection_name=f"memory_{self.user_id}",
                embedding_function=self._embeddings,
                persist_directory=settings.CHROMA_PATH,
            )
        return self._vectorstore

    # ------------------------------------------------------------------
    # Core memory — profile + org context
    # ------------------------------------------------------------------
    async def get_profile(self) -> UserProfile | None:
        result = await self.db.execute(
            select(UserProfile).where(UserProfile.user_id == self.user_id)
        )
        return result.scalar_one_or_none()

    async def upsert_profile(self, fields: dict[str, Any]) -> UserProfile:
        profile = await self.get_profile()
        if profile is None:
            profile = UserProfile(user_id=self.user_id, **fields)
            self.db.add(profile)
        else:
            for key, value in fields.items():
                if hasattr(profile, key):
                    setattr(profile, key, value)
            profile.updated_at = datetime.utcnow()
        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    async def get_org_context(self) -> OrgContext | None:
        result = await self.db.execute(
            select(OrgContext).where(OrgContext.user_id == self.user_id)
        )
        return result.scalar_one_or_none()

    async def upsert_org_context(self, fields: dict[str, Any]) -> OrgContext:
        org = await self.get_org_context()
        if org is None:
            org = OrgContext(user_id=self.user_id, **fields)
            self.db.add(org)
        else:
            for key, value in fields.items():
                if hasattr(org, key):
                    setattr(org, key, value)
            org.updated_at = datetime.utcnow()
        await self.db.commit()
        await self.db.refresh(org)
        return org

    async def build_core_block(self) -> str:
        """Assemble the core memory block for system prompt injection."""
        profile = await self.get_profile()
        org = await self.get_org_context()

        lines: list[str] = []

        if profile:
            lines.append("## User Profile")
            if profile.role:
                lines.append(f"- Role: {profile.role}")
            if profile.team:
                lines.append(f"- Team: {profile.team}")
            if profile.responsibilities:
                lines.append(f"- Responsibilities: {profile.responsibilities}")
            if profile.working_hours:
                lines.append(f"- Working hours: {profile.working_hours}")
            if profile.timezone:
                lines.append(f"- Timezone: {profile.timezone}")
            if profile.communication_style:
                lines.append(f"- Communication style: {profile.communication_style}")

        if org:
            if lines:
                lines.append("")
            lines.append("## Organizational Context")
            if org.org_name:
                lines.append(f"- Organization: {org.org_name}")
            if org.mission:
                lines.append(f"- Mission: {org.mission}")
            if org.current_quarter:
                lines.append(f"- Current quarter: {org.current_quarter}")
            if org.quarter_goals:
                lines.append(f"- Quarter goals:\n{org.quarter_goals}")
            if org.leadership_priorities:
                lines.append(f"- Leadership priorities:\n{org.leadership_priorities}")
            if org.team_okrs:
                lines.append(f"- Team OKRs:\n{org.team_okrs}")

        if not lines:
            return ""
        return "\n".join(lines)

    # ------------------------------------------------------------------
    # Archival memory — facts with semantic recall
    # ------------------------------------------------------------------
    async def write_fact(
        self,
        fact: str,
        source: str = "chat",
        confidence: float = 0.8,
    ) -> MemoryFact:
        """Persist a fact to Postgres + vectorstore for semantic recall."""
        row = MemoryFact(
            user_id=self.user_id,
            fact=fact,
            source=source,
            confidence=confidence,
        )
        self.db.add(row)
        await self.db.commit()
        await self.db.refresh(row)

        try:
            self.vectorstore.add_texts(
                texts=[fact],
                metadatas=[
                    {
                        "fact_id": row.id,
                        "user_id": self.user_id,
                        "source": source,
                        "confidence": confidence,
                    }
                ],
                ids=[row.id],
            )
        except Exception:
            # Don't fail the request if vectorstore write fails —
            # Postgres row is authoritative and re-index is possible later
            pass

        return row

    async def recall(self, query: str, limit: int = 5) -> list[MemoryFact]:
        """Semantic recall from archival memory. Returns MemoryFact rows."""
        try:
            docs = self.vectorstore.similarity_search(query, k=limit)
        except Exception:
            # Fallback to recency-ordered fetch if vectorstore unavailable
            result = await self.db.execute(
                select(MemoryFact)
                .where(MemoryFact.user_id == self.user_id)
                .order_by(MemoryFact.last_accessed.desc())
                .limit(limit)
            )
            return list(result.scalars().all())

        fact_ids = [doc.metadata.get("fact_id") for doc in docs if doc.metadata.get("fact_id")]
        if not fact_ids:
            return []

        result = await self.db.execute(
            select(MemoryFact).where(
                MemoryFact.user_id == self.user_id,
                MemoryFact.id.in_(fact_ids),
            )
        )
        rows = list(result.scalars().all())

        # Preserve similarity ordering
        order = {fid: i for i, fid in enumerate(fact_ids)}
        rows.sort(key=lambda r: order.get(r.id, 999))

        # Bump access counters
        if rows:
            await self.db.execute(
                update(MemoryFact)
                .where(MemoryFact.id.in_([r.id for r in rows]))
                .values(
                    last_accessed=datetime.utcnow(),
                    access_count=MemoryFact.access_count + 1,
                )
            )
            await self.db.commit()

        return rows

    async def list_facts(self, limit: int = 100) -> list[MemoryFact]:
        result = await self.db.execute(
            select(MemoryFact)
            .where(MemoryFact.user_id == self.user_id)
            .order_by(MemoryFact.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def forget_fact(self, fact_id: str) -> bool:
        result = await self.db.execute(
            select(MemoryFact).where(
                MemoryFact.id == fact_id,
                MemoryFact.user_id == self.user_id,
            )
        )
        row = result.scalar_one_or_none()
        if row is None:
            return False

        await self.db.delete(row)
        await self.db.commit()

        try:
            self.vectorstore.delete(ids=[fact_id])
        except Exception:
            pass

        return True

    # ------------------------------------------------------------------
    # Full context builder — used by chat + agents
    # ------------------------------------------------------------------
    async def build_context_for_query(self, query: str) -> str:
        """Assemble core block + recalled archival facts relevant to query."""
        parts: list[str] = []

        core = await self.build_core_block()
        if core:
            parts.append(core)

        recalled = await self.recall(query, limit=5)
        if recalled:
            parts.append("## Relevant Memories")
            for fact in recalled:
                parts.append(f"- {fact.fact}")

        return "\n\n".join(parts)
