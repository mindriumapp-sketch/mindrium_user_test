from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class SudScoreCreate(BaseModel):
    before_sud: int = Field(0, ge=0, le=10)
    after_sud: Optional[int] = Field(None, ge=0, le=10)
    client_timestamp: datetime


class SudScoreUpdate(BaseModel):
    before_sud: Optional[int] = Field(None, ge=0, le=10)
    after_sud: Optional[int] = Field(None, ge=0, le=10)
    client_timestamp: datetime


class SudScoreResponse(BaseModel):
    sud_id: str
    diary_id: Optional[str] = None
    before_sud: int = Field(..., ge=0, le=10)
    after_sud: Optional[int] = Field(None, ge=0, le=10)
    created_at: datetime
    updated_at: datetime

# 추가: 주차별 / 일자별 통계 응답 --------------------
class WeeklySUDStats(BaseModel):
    """주차별 평균 SUD 통계 (전체 환자 or 특정 환자)"""
    weekStart: datetime          # 해당 주차 시작 시각 (KST 기준 주간의 0시를 UTC 변환한 값)
    avgBefore: float             # SUD 전 평균
    avgAfter: Optional[float]    # SUD 후 평균 (없으면 None)
    count: int                    # 집계에 포함된 SUD 레코드 개수


class DailySUDStats(BaseModel):
    """특정 주차 내부의 일자별 평균 SUD 통계"""
    date: datetime                # 해당 날짜 0시 (KST 기준, UTC 변환)
    avgBefore: float
    avgAfter: Optional[float]
    count: int
