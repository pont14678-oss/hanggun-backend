import os
from google import genai

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

client = None

if GEMINI_API_KEY:
    client = genai.Client(api_key=GEMINI_API_KEY)


def ask_gemini(question: str, carpool_text: str) -> str:
    if client is None:
        return (
            "Gemini API 키가 설정되지 않았습니다. "
            "GEMINI_API_KEY 환경변수를 설정해주세요."
        )

    prompt = f"""
너는 '행군(HangGun)' 앱의 예비군 카풀 AI 도우미야.

앱 기능:
- 예비군 카풀 추천
- 예비군 준비물 안내
- 예상 퇴소시간 안내
- 예상 요금 안내
- 카풀 추천 이유 설명

현재 등록된 카풀 목록:
{carpool_text}

사용자 질문:
{question}

답변 조건:
- 한국어로 답변
- 짧고 이해하기 쉽게 답변
- 카풀 관련 질문이면 현재 카풀 목록을 참고
- 예비군 정보 질문이면 일반적인 예비군 정보를 안내
- 확실하지 않은 정보는 "훈련장마다 다를 수 있음"이라고 말하기
"""

    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
    )

    return response.text