from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Sacco, User, Watchlist, WatchlistItem
from ..schemas import WatchlistCreate, WatchlistOut, WatchlistUpdate

router = APIRouter(prefix="/watchlists", tags=["Watchlists"])


def _out(w: Watchlist) -> WatchlistOut:
    return WatchlistOut(id=w.id, name=w.name, created_at=w.created_at,
                        saccos=[i.sacco for i in w.items])


def _get_owned(db: Session, watchlist_id: int, user: User) -> Watchlist:
    w = db.get(Watchlist, watchlist_id)
    # 404 (not 403) for other people's lists so we don't reveal they exist
    if not w or w.user_id != user.id:
        raise HTTPException(404, "Watchlist not found")
    return w


def _set_saccos(db: Session, w: Watchlist, sacco_ids: list[int]) -> None:
    ids = list(dict.fromkeys(sacco_ids))  # remove duplicates, keep order
    found = set(db.scalars(select(Sacco.id).where(Sacco.id.in_(ids))).all()) if ids else set()
    missing = [i for i in ids if i not in found]
    if missing:
        raise HTTPException(404, f"SACCO id(s) not found: {missing}")
    w.items.clear()
    db.flush()
    for i in ids:
        w.items.append(WatchlistItem(sacco_id=i))


@router.post("", response_model=WatchlistOut, status_code=status.HTTP_201_CREATED)
def create_watchlist(data: WatchlistCreate, user: User = Depends(get_current_user),
                     db: Session = Depends(get_db)):
    if db.scalar(select(Watchlist).where(Watchlist.user_id == user.id, Watchlist.name == data.name)):
        raise HTTPException(409, "You already have a watchlist with this name")
    w = Watchlist(user_id=user.id, name=data.name)
    db.add(w)
    db.flush()
    _set_saccos(db, w, data.sacco_ids)
    db.commit()
    db.refresh(w)
    return _out(w)


@router.get("", response_model=list[WatchlistOut])
def list_watchlists(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(Watchlist).where(Watchlist.user_id == user.id)
                      .order_by(Watchlist.created_at)).all()
    return [_out(w) for w in rows]


@router.get("/{watchlist_id}", response_model=WatchlistOut)
def get_watchlist(watchlist_id: int, user: User = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    return _out(_get_owned(db, watchlist_id, user))


@router.put("/{watchlist_id}", response_model=WatchlistOut)
def update_watchlist(watchlist_id: int, data: WatchlistUpdate,
                     user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    w = _get_owned(db, watchlist_id, user)
    if data.name is not None and data.name != w.name:
        if db.scalar(select(Watchlist).where(Watchlist.user_id == user.id, Watchlist.name == data.name)):
            raise HTTPException(409, "You already have a watchlist with this name")
        w.name = data.name
    if data.sacco_ids is not None:
        _set_saccos(db, w, data.sacco_ids)
    db.commit()
    db.refresh(w)
    return _out(w)


@router.delete("/{watchlist_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_watchlist(watchlist_id: int, user: User = Depends(get_current_user),
                     db: Session = Depends(get_db)):
    w = _get_owned(db, watchlist_id, user)
    db.delete(w)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
