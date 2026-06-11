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


class ChatRequest(BaseModel):
    question: str


class PlaceSearchRequest(BaseModel):
    keyword: str


class RouteRequest(BaseModel):
    start_lat: float
    start_lon: float
    end_lat: float
    end_lon: float


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
            driver_phone TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS ride_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            carpool_id INTEGER NOT NULL,
            rider_name TEXT NOT NULL,
            rider_phone TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT '대기',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (carpool_id) REFERENCES carpools(id)
        )
    """)

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


init_db()


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
            driver_phone
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

    cursor.execute("SELECT * FROM carpools ORDER BY id DESC")
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

    cursor.execute(
        """
        INSERT INTO ride_requests (
            carpool_id,
            rider_name,
            rider_phone,
            status
        )
        VALUES (?, ?, ?, ?)
        """,
        (
            carpool_id,
            data.rider_name,
            data.rider_phone,
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
        SELECT *
        FROM ride_requests
        WHERE carpool_id = ?
        ORDER BY id DESC
        """,
        (carpool_id,),
    )

    rows = cursor.fetchall()
    conn.close()

    return [dict(row) for row in rows]


@app.get("/debug/env")
def debug_env():
    return {
        "all_env_keys": list(os.environ.keys()),
        "GEMINI_API_KEY_exists": bool(os.environ.get("GEMINI_API_KEY")),
        "GOOGLE_API_KEY_exists": bool(os.environ.get("GOOGLE_API_KEY")),
        "TMAP_API_KEY_exists": bool(os.environ.get("TMAP_API_KEY")),
    }

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