import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Meeting(Base):
    __tablename__ = "meetings"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String, ForeignKey("users.id"), nullable=False, index=True
    )
    calendar_event_id: Mapped[str | None] = mapped_column(
        String, ForeignKey("calendar_events.id"), nullable=True, index=True
    )
    tree_node_id: Mapped[str | None] = mapped_column(
        String, ForeignKey("tree_nodes.id"), nullable=True, index=True
    )
    title: Mapped[str] = mapped_column(String, nullable=False)
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    attendees: Mapped[list | None] = mapped_column(JSON, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False, default="draft")
    finalized_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    decisions_extracted: Mapped[int] = mapped_column(Integer, default=0)
    follow_ups_extracted: Mapped[int] = mapped_column(Integer, default=0)
    todos_created: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    tree_node = relationship("TreeNode", foreign_keys=[tree_node_id])
    calendar_event = relationship("CalendarEvent", foreign_keys=[calendar_event_id])
