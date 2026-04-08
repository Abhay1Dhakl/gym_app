from __future__ import annotations

import re

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.entities import Organization


def slugify_name(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "gym"


def generate_unique_slug(db: Session, name: str) -> str:
    base_slug = slugify_name(name)
    slug = base_slug
    suffix = 2

    while db.scalar(select(Organization.id).where(Organization.slug == slug)) is not None:
        slug = f"{base_slug}-{suffix}"
        suffix += 1

    return slug
