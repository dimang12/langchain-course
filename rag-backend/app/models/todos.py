import uuid
from datetime import datetime

from sqlalchemy import Boolean, JSON, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TodoFolder(Base):
    __tablename__ = "todo_folders"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    parent_id: Mapped[str | None] = mapped_column(String, ForeignKey("todo_folders.id"), nullable=True, index=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    children: Mapped[list["TodoFolder"]] = relationship(
        back_populates="parent",
        cascade="all, delete-orphan",
        order_by="TodoFolder.sort_order, TodoFolder.name",
    )
    parent: Mapped["TodoFolder | None"] = relationship(
        back_populates="children",
        remote_side=[id],
    )
    statuses: Mapped[list["TodoStatus"]] = relationship(
        back_populates="folder",
        cascade="all, delete-orphan",
        order_by="TodoStatus.sort_order",
    )
    todos: Mapped[list["Todo"]] = relationship(
        back_populates="folder",
        cascade="all, delete-orphan",
    )


class TodoStatus(Base):
    __tablename__ = "todo_statuses"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    folder_id: Mapped[str] = mapped_column(String, ForeignKey("todo_folders.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    color: Mapped[str] = mapped_column(String, nullable=False, default="#7C5CFF")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    folder: Mapped["TodoFolder"] = relationship(back_populates="statuses")
    todos: Mapped[list["Todo"]] = relationship(back_populates="status")


class Todo(Base):
    __tablename__ = "todos"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False, index=True)
    folder_id: Mapped[str | None] = mapped_column(String, ForeignKey("todo_folders.id"), nullable=True, index=True)
    status_id: Mapped[str | None] = mapped_column(String, ForeignKey("todo_statuses.id"), nullable=True, index=True)

    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    priority: Mapped[str] = mapped_column(String, nullable=False, default="medium")  # low | medium | high
    due_date: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    tags: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    # Phase K intelligence connections
    goal_id: Mapped[str | None] = mapped_column(
        String, ForeignKey("goals.id"), nullable=True, index=True
    )
    estimated_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_today_priority: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    folder: Mapped["TodoFolder | None"] = relationship(back_populates="todos")
    status: Mapped["TodoStatus | None"] = relationship(back_populates="todos")
