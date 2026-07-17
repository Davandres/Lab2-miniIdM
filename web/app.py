from flask import Flask, request

app = Flask(__name__)


@app.route("/")
def index():
    usuario = request.headers.get("X-Remote-User", "desconocido")
    return (
        f"Autenticado via Kerberos como: {usuario}\n"
        "Infraestructura de Identidad Segura para la FIS\n"
    )


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
