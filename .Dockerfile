FROM dart:stable

WORKDIR /app

COPY . .

RUN dart pub get

CMD ["dart", "lib/app.dart"]
