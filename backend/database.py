from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = "sqlite:///./hanggun.db"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


class Carpool(Base):
    __tablename__ = "carpools"

    id = Column(Integer, primary_key=True, index=True)
    departure = Column(String, nullable=False)
    destination = Column(String, nullable=False)
    time = Column(String, nullable=False)
    max_seats = Column(Integer, nullable=False)
    current_seats = Column(Integer, default=1)
    minutes = Column(Integer, default=45)
    fare = Column(Integer, default=5000)
    match = Column(Integer, default=90)


def create_tables():
    Base.metadata.create_all(bind=engine)