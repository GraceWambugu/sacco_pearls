from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import require_admin
from ..models import Sacco, SaccoAlias
from ..schemas import SaccoCreate, SaccoOut, SaccoUpdate
from ..utils import normalize_name

router = APIRouter(prefix="/saccos", tags=["SACCOs"])


@router.get("", response_model=list[SaccoOut])
def list_saccos(
    q: Optional[str] = Query(None, description="search by name"),
    county: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    stmt = select(Sacco).where(Sacco.is_archived.is_(False))
    if q:
        stmt = stmt.where(Sacco.name.ilike(f"%{q}%"))
    if county:
        stmt = stmt.where(Sacco.county.ilike(county))
    return db.scalars(stmt.order_by(Sacco.name).offset(skip).limit(limit)).all()


@router.get("/archived", response_model=list[SaccoOut], dependencies=[Depends(require_admin)])
def list_archived_saccos(
    q: Optional[str] = Query(None, description="search by name"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    stmt = select(Sacco).where(Sacco.is_archived.is_(True))
    if q:
        stmt = stmt.where(Sacco.name.ilike(f"%{q}%"))
    return db.scalars(stmt.order_by(Sacco.name).offset(skip).limit(limit)).all()


@router.get("/{sacco_id}", response_model=SaccoOut)
def get_sacco(sacco_id: int, db: Session = Depends(get_db)):
    sacco = db.get(Sacco, sacco_id)
    if not sacco or sacco.is_archived:
        raise HTTPException(404, "SACCO not found")
    return sacco


@router.post("", response_model=SaccoOut, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(require_admin)])
def create_sacco(data: SaccoCreate, db: Session = Depends(get_db)):
    if db.scalar(select(Sacco).where(Sacco.name == data.name)):
        raise HTTPException(409, "A SACCO with this name already exists")
    sacco = Sacco(name=data.name, county=data.county)
    db.add(sacco)
    db.flush()
    key = normalize_name(data.name)
    if not db.scalar(select(SaccoAlias).where(SaccoAlias.alias == key)):
        db.add(SaccoAlias(sacco_id=sacco.id, alias=key))
    db.commit()
    db.refresh(sacco)
    return sacco


@router.put("/{sacco_id}", response_model=SaccoOut, dependencies=[Depends(require_admin)])
def update_sacco(sacco_id: int, data: SaccoUpdate, db: Session = Depends(get_db)):
    sacco = db.get(Sacco, sacco_id)
    if not sacco or sacco.is_archived:
        raise HTTPException(404, "SACCO not found")
    if data.name is not None and data.name != sacco.name:
        if db.scalar(select(Sacco).where(Sacco.name == data.name)):
            raise HTTPException(409, "A SACCO with this name already exists")
        sacco.name = data.name
    if data.county is not None:
        sacco.county = data.county
    db.commit()
    db.refresh(sacco)
    return sacco


@router.delete("/{sacco_id}", status_code=status.HTTP_204_NO_CONTENT,
               dependencies=[Depends(require_admin)])
def delete_sacco(sacco_id: int, db: Session = Depends(get_db)):
    sacco = db.get(Sacco, sacco_id)
    if not sacco or sacco.is_archived:
        raise HTTPException(404, "SACCO not found")
    sacco.is_archived = True
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{sacco_id}/restore", response_model=SaccoOut,
             dependencies=[Depends(require_admin)])
def restore_sacco(sacco_id: int, db: Session = Depends(get_db)):
    sacco = db.get(Sacco, sacco_id)
    if not sacco:
        raise HTTPException(404, "SACCO not found")
    sacco.is_archived = False
    db.commit()
    db.refresh(sacco)
    return sacco
