FROM debian:latest

RUN apt update && apt install -y python3 python3-libgpiod

COPY "./gpiod-test.py" "/gpiod-test.py"

CMD ["python3", "gpiod-test.py"]    