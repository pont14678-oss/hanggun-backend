import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import sqlite3
import requests
import math
import google.generativeai as genai

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_NAME = "hanggun.db"
TMAP_API_KEY = os.getenv("TMAP_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel("models/gemini-2.5-flash")


class CarpoolCreate(BaseModel):
    departure: str
    destination: str
    time: str
    max_seats: int
    departure_lat: float | None = None
    departure_lon: float | None = None
    destination_lat: float | None = None
    destination_lon: float | None = None
    driver_name: str | None = None
    driver_phone: str | None = None


class RideRequestCreate(BaseModel):
    rider_name: str
    rider_phone: str
    pickup_location: str | None = None
    pickup_lat: float | None = None
    pickup_lon: float | None = None


class ChatRequest(BaseModel):
    question: str


class PlaceSearchRequest(BaseModel):
    keyword: str


class RouteRequest(BaseModel):
    start_lat: float
    start_lon: float
    end_lat: float
    end_lon: float


class ReverseGeocodeRequest(BaseModel):
    lat: float
    lon: float


class DriverLocationUpdate(BaseModel):
    driver_lat: float
    driver_lon: float
    driver_location: str | None = None


class ReleaseReportCreate(BaseModel):
    training_center: str
    training_type: str
    reserve_year: str
    weather: str
    release_time: str
    source_type: str | None = "user"


def add_column_if_not_exists(cursor, table_name, column_name, column_type):
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = [row[1] for row in cursor.fetchall()]

    if column_name not in columns:
        cursor.execute(
            f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"
        )


def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS carpools (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            departure TEXT NOT NULL,
            destination TEXT NOT NULL,
            time TEXT NOT NULL,
            maxSeats INTEGER NOT NULL,
            currentSeats INTEGER NOT NULL DEFAULT 1,
            minutes INTEGER DEFAULT 45,
            distanceKm REAL DEFAULT 0,
            fare INTEGER DEFAULT 5000,
            match INTEGER DEFAULT 90,
            departure_lat REAL,
            departure_lon REAL,
            destination_lat REAL,
            destination_lon REAL,
            driver_name TEXT,
            driver_phone TEXT,
            driver_lat REAL,
            driver_lon REAL,
            driver_location TEXT,
            driver_location_updated_at TIMESTAMP
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS ride_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            carpool_id INTEGER NOT NULL,
            rider_name TEXT NOT NULL,
            rider_phone TEXT NOT NULL,
            pickup_location TEXT,
            pickup_lat REAL,
            pickup_lon REAL,
            status TEXT NOT NULL DEFAULT '대기',
            ride_completed INTEGER NOT NULL DEFAULT 0,
            completed_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (carpool_id) REFERENCES carpools(id)
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS release_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            training_center TEXT NOT NULL,
            training_type TEXT NOT NULL,
            reserve_year TEXT NOT NULL,
            weather TEXT,
            release_time TEXT NOT NULL,
            source_type TEXT DEFAULT 'user',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    add_column_if_not_exists(cursor, "ride_requests", "pickup_location", "TEXT")
    add_column_if_not_exists(cursor, "ride_requests", "pickup_lat", "REAL")
    add_column_if_not_exists(cursor, "ride_requests", "pickup_lon", "REAL")
    add_column_if_not_exists(cursor, "ride_requests", "ride_completed", "INTEGER NOT NULL DEFAULT 0")
    add_column_if_not_exists(cursor, "ride_requests", "completed_at", "TIMESTAMP")

    add_column_if_not_exists(cursor, "carpools", "driver_lat", "REAL")
    add_column_if_not_exists(cursor, "carpools", "driver_lon", "REAL")
    add_column_if_not_exists(cursor, "carpools", "driver_location", "TEXT")
    add_column_if_not_exists(cursor, "carpools", "driver_location_updated_at", "TIMESTAMP")
    add_column_if_not_exists(cursor, "carpools", "status", "TEXT DEFAULT '모집중'")
    add_column_if_not_exists(cursor, "carpools", "completed_at", "TIMESTAMP")

    conn.commit()
    conn.close()


def calculate_route(start_lat, start_lon, end_lat, end_lon):
    url = "https://apis.openapi.sk.com/tmap/routes"

    headers = {
        "appKey": TMAP_API_KEY,
        "Content-Type": "application/json",
    }

    body = {
        "version": 1,
        "startX": start_lon,
        "startY": start_lat,
        "endX": end_lon,
        "endY": end_lat,
        "reqCoordType": "WGS84GEO",
        "resCoordType": "WGS84GEO",
        "searchOption": 0,
        "trafficInfo": "Y",
    }

    response = requests.post(url, headers=headers, json=body)

    if response.status_code != 200:
        return {
            "success": False,
            "minutes": 45,
            "distanceKm": 0,
            "message": "TMAP 경로 계산 실패",
            "status_code": response.status_code,
            "body": response.text,
        }

    data = response.json()
    features = data.get("features", [])

    if not features:
        return {
            "success": False,
            "minutes": 45,
            "distanceKm": 0,
            "message": "경로 정보 없음",
        }

    properties = features[0].get("properties", {})

    total_time_seconds = properties.get("totalTime", 2700)
    total_distance_meter = properties.get("totalDistance", 0)

    minutes = math.ceil(total_time_seconds / 60)
    distance_km = round(total_distance_meter / 1000, 1)

    return {
        "success": True,
        "minutes": minutes,
        "distanceKm": distance_km,
    }

def seed_release_dataset():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM release_reports WHERE source_type = 'seed'")
    count = cursor.fetchone()[0]

    if count > 0:
        conn.close()
        return

    seed_data = [
        ("춘천과학화예비군훈련장", "학생예비군", "학생", "맑음", "16:25"),
        ("춘천과학화예비군훈련장", "학생예비군", "학생", "흐림", "16:40"),
        ("춘천과학화예비군훈련장", "기본훈련", "5년차", "맑음", "16:55"),
        ("춘천과학화예비군훈련장", "기본훈련", "6년차", "비", "17:10"),
        ("춘천과학화예비군훈련장", "작계훈련", "5년차", "맑음", "15:10"),

        ("수원화성오산과학화예비군훈련장", "학생예비군", "학생", "맑음", "16:30"),
        ("수원화성오산과학화예비군훈련장", "학생예비군", "학생", "흐림", "16:45"),
        ("수원화성오산과학화예비군훈련장", "기본훈련", "5년차", "맑음", "17:05"),
        ("수원화성오산과학화예비군훈련장", "기본훈련", "6년차", "비", "17:20"),
        ("수원화성오산과학화예비군훈련장", "작계훈련", "6년차", "흐림", "15:25"),

        ("안양박달과학화예비군훈련장", "학생예비군", "학생", "맑음", "16:20"),
        ("안양박달과학화예비군훈련장", "기본훈련", "5년차", "맑음", "16:50"),
        ("안양박달과학화예비군훈련장", "기본훈련", "6년차", "흐림", "17:00"),
        ("안양박달과학화예비군훈련장", "작계훈련", "5년차", "비", "15:30"),

        ("강릉예비군훈련장", "학생예비군", "학생", "맑음", "16:35"),
        ("강릉예비군훈련장", "기본훈련", "5년차", "흐림", "17:05"),
        ("강릉예비군훈련장", "기본훈련", "6년차", "비", "17:25"),
        ("강릉예비군훈련장", "작계훈련", "6년차", "맑음", "15:20"),

        ("금곡예비군훈련장", "학생예비군", "학생", "맑음", "16:25"),
        ("금곡예비군훈련장", "기본훈련", "5년차", "맑음", "16:55"),
        ("금곡예비군훈련장", "기본훈련", "6년차", "흐림", "17:15"),
        ("금곡예비군훈련장", "작계훈련", "5년차", "비", "15:35"),
    ]

    cursor.executemany(
        """
        INSERT INTO release_reports (
            training_center,
            training_type,
            reserve_year,
            weather,
            release_time,
            source_type
        )
        VALUES (?, ?, ?, ?, ?, 'seed')
        """,
        seed_data,
    )

    conn.commit()
    conn.close()

def reverse_geocode_address(lat, lon):
    url = "https://apis.openapi.sk.com/tmap/geo/reversegeocoding"

    headers = {
        "appKey": TMAP_API_KEY,
    }

    params = {
        "version": "1",
        "lat": lat,
        "lon": lon,
        "coordType": "WGS84GEO",
        "addressType": "A10",
    }

    response = requests.get(url, headers=headers, params=params)

    if response.status_code != 200:
        return "현재 위치"

    data = response.json()
    address_info = data.get("addressInfo", {})

    full_address = address_info.get("fullAddress")

    if full_address:
        return full_address

    city = address_info.get("city_do", "")
    gu = address_info.get("gu_gun", "")
    dong = address_info.get("legalDong", "")

    address = f"{city} {gu} {dong}".strip()

    return address or "현재 위치"


init_db()
seed_release_dataset()


@app.get("/")
def home():
    return {"message": "HangGun backend running"}


@app.post("/carpools")
def create_carpool(data: CarpoolCreate):
    minutes = 45
    distance_km = 0

    if (
        data.departure_lat is not None
        and data.departure_lon is not None
        and data.destination_lat is not None
        and data.destination_lon is not None
    ):
        route = calculate_route(
            data.departure_lat,
            data.departure_lon,
            data.destination_lat,
            data.destination_lon,
        )

        if route["success"]:
            minutes = route["minutes"]
            distance_km = route["distanceKm"]

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute(
        """
        INSERT INTO carpools (
            departure,
            destination,
            time,
            maxSeats,
            currentSeats,
            minutes,
            distanceKm,
            fare,
            match,
            departure_lat,
            departure_lon,
            destination_lat,
            destination_lon,
            driver_name,
            driver_phone,
            status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            data.departure,
            data.destination,
            data.time,
            data.max_seats,
            1,
            minutes,
            distance_km,
            5000,
            90,
            data.departure_lat,
            data.departure_lon,
            data.destination_lat,
            data.destination_lon,
            data.driver_name,
            data.driver_phone,
            "모집중",
        ),
    )

    conn.commit()
    carpool_id = cursor.lastrowid
    conn.close()

    return {
        "id": carpool_id,
        "departure": data.departure,
        "destination": data.destination,
        "time": data.time,
        "maxSeats": data.max_seats,
        "currentSeats": 1,
        "minutes": minutes,
        "distanceKm": distance_km,
        "fare": 5000,
        "match": 90,
        "departure_lat": data.departure_lat,
        "departure_lon": data.departure_lon,
        "destination_lat": data.destination_lat,
        "destination_lon": data.destination_lon,
        "driver_name": data.driver_name,
        "driver_phone": data.driver_phone,
    }


@app.get("/carpools")
def get_carpools():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("""
    SELECT *
    FROM carpools
    WHERE status IS NULL OR status != '완료'
    ORDER BY id DESC
""")
    rows = cursor.fetchall()

    conn.close()

    return [dict(row) for row in rows]


@app.post("/carpools/{carpool_id}/join")
def join_carpool(carpool_id: int, data: RideRequestCreate):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (carpool_id,))
    carpool = cursor.fetchone()

    if carpool is None:
        conn.close()
        raise HTTPException(status_code=404, detail="카풀을 찾을 수 없습니다.")

    if carpool["currentSeats"] >= carpool["maxSeats"]:
        conn.close()
        raise HTTPException(status_code=400, detail="이미 만석입니다.")

    pickup_location = data.pickup_location

    if (
        (pickup_location is None or pickup_location == "현재 위치")
        and data.pickup_lat is not None
        and data.pickup_lon is not None
    ):
        pickup_location = reverse_geocode_address(data.pickup_lat, data.pickup_lon)

    cursor.execute(
        """
        INSERT INTO ride_requests (
            carpool_id,
            rider_name,
            rider_phone,
            pickup_location,
            pickup_lat,
            pickup_lon,
            status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            carpool_id,
            data.rider_name,
            data.rider_phone,
            pickup_location,
            data.pickup_lat,
            data.pickup_lon,
            "대기",
        ),
    )

    conn.commit()
    request_id = cursor.lastrowid

    cursor.execute("SELECT * FROM ride_requests WHERE id = ?", (request_id,))
    request = cursor.fetchone()

    conn.close()

    return {
        "success": True,
        "message": "탑승 신청이 접수되었습니다.",
        "request": dict(request),
    }


@app.get("/carpools/{carpool_id}/requests")
def get_ride_requests(carpool_id: int):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (carpool_id,))
    carpool = cursor.fetchone()

    if carpool is None:
        conn.close()
        raise HTTPException(status_code=404, detail="카풀을 찾을 수 없습니다.")

    cursor.execute(
        """
        SELECT
            r.id,
            r.carpool_id,
            r.rider_name,
            r.rider_phone,
            r.pickup_location,
            r.pickup_lat,
            r.pickup_lon,
            r.status,
            r.ride_completed,
            r.completed_at,
            r.created_at,
            c.departure,
            c.destination,
            c.time,
            c.driver_name,
            c.driver_phone,
            c.driver_lat,
            c.driver_lon,
            c.driver_location,
            c.driver_location_updated_at
        FROM ride_requests r
        JOIN carpools c ON r.carpool_id = c.id
        WHERE r.carpool_id = ?
        ORDER BY r.id DESC
        """,
        (carpool_id,),
    )

    rows = cursor.fetchall()
    conn.close()

    return [dict(row) for row in rows]


@app.post("/requests/{request_id}/approve")
def approve_request(request_id: int):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM ride_requests WHERE id = ?", (request_id,))
    request = cursor.fetchone()

    if request is None:
        conn.close()
        raise HTTPException(status_code=404, detail="신청을 찾을 수 없습니다.")

    if request["status"] == "승인":
        conn.close()
        raise HTTPException(status_code=400, detail="이미 승인된 신청입니다.")

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (request["carpool_id"],))
    carpool = cursor.fetchone()

    if carpool is None:
        conn.close()
        raise HTTPException(status_code=404, detail="카풀을 찾을 수 없습니다.")

    if carpool["currentSeats"] >= carpool["maxSeats"]:
        conn.close()
        raise HTTPException(status_code=400, detail="이미 만석입니다.")

    cursor.execute(
        "UPDATE ride_requests SET status = ? WHERE id = ?",
        ("승인", request_id),
    )

    cursor.execute(
        "UPDATE carpools SET currentSeats = currentSeats + 1 WHERE id = ?",
        (request["carpool_id"],),
    )

    conn.commit()

    cursor.execute("SELECT * FROM ride_requests WHERE id = ?", (request_id,))
    updated_request = cursor.fetchone()

    conn.close()

    return {
        "success": True,
        "message": "탑승 신청을 승인했습니다.",
        "request": dict(updated_request),
    }


@app.post("/requests/{request_id}/reject")
def reject_request(request_id: int):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM ride_requests WHERE id = ?", (request_id,))
    request = cursor.fetchone()

    if request is None:
        conn.close()
        raise HTTPException(status_code=404, detail="신청을 찾을 수 없습니다.")

    if request["status"] == "승인":
        conn.close()
        raise HTTPException(status_code=400, detail="이미 승인된 신청은 거절할 수 없습니다.")

    cursor.execute(
        "UPDATE ride_requests SET status = ? WHERE id = ?",
        ("거절", request_id),
    )

    conn.commit()

    cursor.execute("SELECT * FROM ride_requests WHERE id = ?", (request_id,))
    updated_request = cursor.fetchone()

    conn.close()

    return {
        "success": True,
        "message": "탑승 신청을 거절했습니다.",
        "request": dict(updated_request),
    }


@app.post("/requests/{request_id}/complete")
def complete_request(request_id: int):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM ride_requests WHERE id = ?", (request_id,))
    request = cursor.fetchone()

    if request is None:
        conn.close()
        raise HTTPException(status_code=404, detail="신청을 찾을 수 없습니다.")

    if request["status"] != "승인":
        conn.close()
        raise HTTPException(status_code=400, detail="승인된 신청만 탑승 완료 처리할 수 있습니다.")

    cursor.execute(
        """
        UPDATE ride_requests
        SET ride_completed = 1,
            completed_at = CURRENT_TIMESTAMP
        WHERE id = ?
        """,
        (request_id,),
    )

    conn.commit()

    cursor.execute("SELECT * FROM ride_requests WHERE id = ?", (request_id,))
    updated_request = cursor.fetchone()

    conn.close()

    return {
        "success": True,
        "message": "탑승 완료 처리되었습니다.",
        "request": dict(updated_request),
    }

@app.post("/carpools/{carpool_id}/complete")
def complete_carpool(carpool_id: int):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (carpool_id,))
    carpool = cursor.fetchone()

    if carpool is None:
        conn.close()
        raise HTTPException(status_code=404, detail="카풀을 찾을 수 없습니다.")

    cursor.execute(
        """
        UPDATE carpools
        SET status = '완료',
            completed_at = CURRENT_TIMESTAMP
        WHERE id = ?
        """,
        (carpool_id,),
    )

    cursor.execute(
        """
        UPDATE ride_requests
        SET ride_completed = 1,
            completed_at = CURRENT_TIMESTAMP
        WHERE carpool_id = ?
          AND status = '승인'
        """,
        (carpool_id,),
    )

    conn.commit()

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (carpool_id,))
    updated_carpool = cursor.fetchone()

    conn.close()

    return {
        "success": True,
        "message": "운행이 완료되었습니다.",
        "carpool": dict(updated_carpool),
    }

@app.post("/carpools/{carpool_id}/driver-location")
def update_driver_location(carpool_id: int, data: DriverLocationUpdate):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (carpool_id,))
    carpool = cursor.fetchone()

    if carpool is None:
        conn.close()
        raise HTTPException(status_code=404, detail="카풀을 찾을 수 없습니다.")

    driver_location = data.driver_location

    if driver_location is None or driver_location == "현재 위치":
        driver_location = reverse_geocode_address(data.driver_lat, data.driver_lon)

    cursor.execute(
        """
        UPDATE carpools
        SET driver_lat = ?,
            driver_lon = ?,
            driver_location = ?,
            driver_location_updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
        """,
        (
            data.driver_lat,
            data.driver_lon,
            driver_location,
            carpool_id,
        ),
    )

    conn.commit()

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (carpool_id,))
    updated_carpool = cursor.fetchone()

    conn.close()

    return {
        "success": True,
        "message": "운전자 위치가 저장되었습니다.",
        "carpool": dict(updated_carpool),
    }

@app.get("/carpools/{carpool_id}/pickup-recommendation")
def recommend_pickup_place(carpool_id: int):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM carpools WHERE id = ?", (carpool_id,))
    carpool = cursor.fetchone()

    if carpool is None:
        conn.close()
        raise HTTPException(status_code=404, detail="카풀을 찾을 수 없습니다.")

    cursor.execute(
        """
        SELECT *
        FROM ride_requests
        WHERE carpool_id = ?
          AND pickup_lat IS NOT NULL
          AND pickup_lon IS NOT NULL
          AND status != '거절'
        """,
        (carpool_id,),
    )

    requests = cursor.fetchall()
    conn.close()

    points = []

    if carpool["departure_lat"] is not None and carpool["departure_lon"] is not None:
        points.append({
            "name": "운전자 출발지",
            "lat": carpool["departure_lat"],
            "lon": carpool["departure_lon"],
            "location": carpool["departure"],
        })

    for r in requests:
        points.append({
            "name": r["rider_name"],
            "lat": r["pickup_lat"],
            "lon": r["pickup_lon"],
            "location": r["pickup_location"],
        })

    if len(points) < 2:
        raise HTTPException(
            status_code=400,
            detail="추천을 위해서는 운전자 출발지와 신청자 위치가 필요합니다.",
        )

    avg_lat = sum(float(p["lat"]) for p in points) / len(points)
    avg_lon = sum(float(p["lon"]) for p in points) / len(points)

    address = reverse_geocode_address(avg_lat, avg_lon)

    point_text = ""
    for p in points:
        point_text += (
            f"\n- {p['name']}: {p['location']} "
            f"(위도 {p['lat']}, 경도 {p['lon']})"
        )

    prompt = f"""
너는 예비군 카풀 앱 행군(HangGun)의 AI 픽업 장소 추천 도우미다.

카풀 정보:
- 출발지: {carpool['departure']}
- 목적지: {carpool['destination']}
- 출발 시간: {carpool['time']}

참여자 위치:
{point_text}

계산된 중간 지점 주소:
{address}

답변 규칙:
1. 한국어로 답변한다.
2. 운전자와 탑승자가 만나기 좋은 픽업 장소를 1곳 추천한다.
3. 장소명은 너무 길지 않게 쓴다.
4. 추천 이유는 2~3문장으로 쓴다.
5. 실제 위치를 모르면 중간 지점 주소를 기준으로 설명한다.
6. 형식은 반드시 아래처럼 작성한다.

추천 장소: 장소명
추천 이유: 이유
"""

    try:
        response = model.generate_content(prompt)
        ai_text = response.text or ""
    except Exception:
        ai_text = ""

    recommended_place = address
    reason = "운전자 출발지와 신청자 위치들의 중간 지점에 가까워 합류하기 좋은 위치입니다."

    if "추천 장소:" in ai_text:
        try:
            recommended_place = ai_text.split("추천 장소:")[1].split("추천 이유:")[0].strip()
        except Exception:
            recommended_place = address

    if "추천 이유:" in ai_text:
        try:
            reason = ai_text.split("추천 이유:")[1].strip()
        except Exception:
            pass

    return {
        "success": True,
        "recommended_place": recommended_place,
        "recommended_address": address,
        "recommended_lat": avg_lat,
        "recommended_lon": avg_lon,
        "reason": reason,
        "participants_count": len(points),
    }

@app.get("/my-rides/{phone}")
def get_my_rides(phone: str):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT
            r.id AS request_id,
            r.carpool_id,
            r.rider_name,
            r.rider_phone,
            r.pickup_location,
            r.pickup_lat,
            r.pickup_lon,
            r.status,
            r.ride_completed,
            r.completed_at,
            r.created_at,
            c.departure,
            c.destination,
            c.time,
            c.maxSeats,
            c.currentSeats,
            c.minutes,
            c.distanceKm,
            c.fare,
            c.driver_name,
            c.driver_phone,
            c.driver_lat,
            c.driver_lon,
            c.driver_location,
            c.driver_location_updated_at
        FROM ride_requests r
        JOIN carpools c ON r.carpool_id = c.id
        WHERE r.rider_phone = ?
        ORDER BY r.id DESC
        """,
        (phone,),
    )

    rows = cursor.fetchall()
    conn.close()

    return [dict(row) for row in rows]

@app.post("/release-report")
def create_release_report(data: ReleaseReportCreate):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute(
        """
        INSERT INTO release_reports (
            training_center,
            training_type,
            reserve_year,
            weather,
            release_time,
            source_type
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            data.training_center,
            data.training_type,
            data.reserve_year,
            data.weather,
            data.release_time,
            data.source_type or "user",
        ),
    )

    conn.commit()
    report_id = cursor.lastrowid
    conn.close()

    return {
        "success": True,
        "message": "퇴소시간 제보가 저장되었습니다.",
        "id": report_id,
    }


@app.get("/release-prediction")
def get_release_prediction(training_center: str, training_type: str):
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT *
        FROM release_reports
        WHERE training_center = ?
          AND training_type = ?
        ORDER BY id DESC
        """,
        (training_center, training_type),
    )

    rows = cursor.fetchall()
    conn.close()

    if len(rows) == 0:
        raise HTTPException(
            status_code=404,
            detail="해당 훈련장과 훈련종류의 데이터가 없습니다.",
        )

    total_minutes = 0

    for row in rows:
        hour, minute = row["release_time"].split(":")
        total_minutes += int(hour) * 60 + int(minute)

    avg_minutes = round(total_minutes / len(rows))
    avg_hour = avg_minutes // 60
    avg_minute = avg_minutes % 60
    predicted_time = f"{avg_hour:02d}:{avg_minute:02d}"

    recent_text = ""
    for row in rows[:10]:
        recent_text += (
            f"\n- 훈련장:{row['training_center']}, "
            f"훈련종류:{row['training_type']}, "
            f"연차:{row['reserve_year']}, "
            f"날씨:{row['weather']}, "
            f"퇴소시간:{row['release_time']}, "
            f"데이터:{row['source_type']}"
        )

    prompt = f"""
너는 예비군 카풀 앱 행군(HangGun)의 AI 퇴소시간 예측 도우미다.

훈련장: {training_center}
훈련종류: {training_type}
데이터 수: {len(rows)}건
평균 퇴소시간: {predicted_time}

최근 데이터:
{recent_text}

답변 규칙:
1. 한국어로 답변한다.
2. 예상 퇴소시간을 먼저 말한다.
3. 데이터 수와 평균값을 근거로 설명한다.
4. 너무 길지 않게 3~5문장으로 말한다.
5. 실제 상황에 따라 달라질 수 있음을 짧게 언급한다.
"""

    try:
        response = model.generate_content(prompt)
        explanation = response.text or "데이터 평균을 기준으로 예측했습니다."
    except Exception:
        explanation = "데이터 평균을 기준으로 예측했습니다."

    return {
        "success": True,
        "training_center": training_center,
        "training_type": training_type,
        "predicted_release_time": predicted_time,
        "data_count": len(rows),
        "explanation": explanation,
        "reports": [dict(row) for row in rows[:10]],
    }

@app.post("/tmap/search")
def search_place(req: PlaceSearchRequest):
    url = "https://apis.openapi.sk.com/tmap/pois"

    headers = {
        "appKey": TMAP_API_KEY,
    }

    params = {
        "version": "1",
        "searchKeyword": req.keyword,
        "resCoordType": "WGS84GEO",
        "reqCoordType": "WGS84GEO",
        "count": 10,
    }

    response = requests.get(url, headers=headers, params=params)

    if response.status_code != 200:
        return {
            "success": False,
            "message": "TMAP 장소 검색 실패",
            "status_code": response.status_code,
            "body": response.text,
        }

    data = response.json()
    pois = data.get("searchPoiInfo", {}).get("pois", {}).get("poi", [])

    results = []

    for poi in pois:
        address_list = poi.get("newAddressList", {}).get("newAddress", [])
        address = ""

        if address_list:
            address = address_list[0].get("fullAddressRoad", "")

        results.append({
            "name": poi.get("name"),
            "address": address,
            "lat": poi.get("frontLat"),
            "lon": poi.get("frontLon"),
        })

    return {
        "success": True,
        "results": results,
    }


@app.post("/tmap/reverse-geocode")
def reverse_geocode(req: ReverseGeocodeRequest):
    address = reverse_geocode_address(req.lat, req.lon)

    return {
        "success": True,
        "address": address,
    }


@app.post("/tmap/route")
def route(req: RouteRequest):
    result = calculate_route(
        req.start_lat,
        req.start_lon,
        req.end_lat,
        req.end_lon,
    )

    return result


@app.post("/ai/chat")
def ai_chat(req: ChatRequest):
    question = req.question

    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("""
        SELECT *
        FROM carpools
        ORDER BY match DESC
        LIMIT 20
    """)

    carpools = [dict(row) for row in cursor.fetchall()]
    conn.close()

    if len(carpools) == 0:
        carpool_text = "현재 등록된 카풀이 없습니다."
    else:
        carpool_text = ""

        for c in carpools:
            left_seats = c["maxSeats"] - c["currentSeats"]

            carpool_text += (
                f"\n- 카풀 ID:{c['id']}, "
                f"출발지:{c['departure']}, "
                f"목적지:{c['destination']}, "
                f"출발시간:{c['time']}, "
                f"남은좌석:{left_seats}, "
                f"거리:{c['distanceKm']}km, "
                f"소요시간:{c['minutes']}분, "
                f"요금:{c['fare']}원, "
                f"매칭률:{c['match']}%"
            )

    prompt = f"""
너는 행군(HangGun) 예비군 카풀 앱의 AI 비서다.

현재 등록된 카풀 정보:
{carpool_text}

사용자 질문:
{question}

답변 규칙:
1. 반드시 한국어로 답변한다.
2. 예비군 이동, 카풀 추천, 준비물, 훈련장 이동 도움에 초점을 맞춘다.
3. 사용자가 카풀 추천을 물으면 현재 등록된 카풀 정보 안에서만 추천한다.
4. 남은 좌석이 0 이하인 카풀은 추천하지 않는다.
5. 카풀 정보가 없으면 없다고 솔직히 말한다.
6. 답변은 너무 길지 않게 3~6문장 정도로 한다.
7. 실제 앱 사용자에게 말하듯 자연스럽고 친절하게 답변한다.
"""

    try:
        response = model.generate_content(prompt)

        if not response.text:
            return {
                "answer": "AI 답변을 생성하지 못했습니다. 다시 질문해주세요."
            }

        return {
            "answer": response.text
        }

    except Exception as e:
        return {
            "answer": f"AI 오류 발생: {str(e)}"
        }