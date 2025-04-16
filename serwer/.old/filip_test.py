import smtplib
from email.mime.text import MIMEText
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import secrets
from dotenv import load_dotenv
import os
from datetime import datetime
import base64
import socket

load_dotenv()

hostname = socket.gethostname()
local_ip = socket.gethostbyname(hostname)

def get_local_ip():
    try:
        # Tworzymy połączenie z adresem zewnętrznym bez rzeczywistego wysyłania danych
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))  # "8.8.8.8" to publiczny serwer Google DNS
            local_ip = s.getsockname()[0]  # Pobieramy adres IP przypisany do aktywnego interfejsu
        return local_ip
    except Exception as e:
        print(f"Błąd: {e}")
        return None

def get_connection():
    global mydb
    if not mydb.is_connected():
        try:
            mydb.reconnect()
            print("Połączenie z bazą danych zostało odnowione.")
        except Exception as e:
            print(f"Błąd podczas odnawiania połączenia: {e}")
            raise e
    return mydb



app = Flask(__name__)
CORS(app)

#Konfiguracja połączenia z bazą danych
mydb = mysql.connector.connect(
    host= os.getenv("DB_HOST"),
    user= os.getenv("DB_USER"),
    password= os.getenv("DB_PASSWORD"),
    database= os.getenv("DB_NAME"),
    auth_plugin="caching_sha2_password"
)

# mydb = mysql.connector.connect(
#     host= 'localhost',
#     user= "root",
#     password= "",
#     database= "userdatabse"
# )

MAIL_USERNAME = os.getenv("MAIL_DEFAULT_SENDER")
MAIL_PASSWORD = os.getenv("MAIL_PASSWORD")

@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        imie = data['name']
        nazwisko = data['surname']
        wiek = data['age']
        nickname = data['nickname']
        email = data['email']
        password = data['password']

        # if wiek < 16:
        #     return jsonify({'error': 'Minimalny wiek to 16 lat'}), 400

        cursor = mydb.cursor()
        # Generowanie unikalnego tokenu weryfikacyjnego
        verification_token = secrets.token_urlsafe(32)

        sql = """
        INSERT INTO users (nickname, imie, nazwisko, wiek, email, password, is_verified, verification_token)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        val = (nickname, imie, nazwisko, wiek, email, password, 0, verification_token)
        cursor.execute(sql, val)
        mydb.commit()

        # Wysyłanie e-maila weryfikacyjnego
        verification_link = f"http://{get_local_ip()}:5000/verify_email?token={verification_token},"
        msg = MIMEText(f"Kliknij poniższy link, aby zweryfikować swój adres e-mail: \n{verification_link}", _charset="utf-8")
        msg['Subject'] = "Weryfikacja adresu e-mail"
        msg['From'] = MAIL_USERNAME
        msg['To'] = email
        # print(f"MAIL_USERNAME: {MAIL_USERNAME}, MAIL_PASSWORD: {MAIL_PASSWORD}")
        print(f"MAIL_USERNAME: {MAIL_USERNAME}")
        print(f"email: {email}")
        print(f"Subject: Weryfikacja adresu e-mail")
        print(f"Verification link: {verification_link}")
        print(f"get_local_ip: {get_local_ip()}")

        try:
            server = smtplib.SMTP('smtp.gmail.com', 587)
            server.starttls()
            server.login(MAIL_USERNAME, MAIL_PASSWORD)
            server.send_message(msg)
            server.quit()
        except Exception as e:
            return jsonify({'error': f"Nie udało się wysłać e-maila: {str(e)}"}), 500

        return jsonify({'message': 'Użytkownik zarejestrowany. Sprawdź swoją skrzynkę e-mail, aby zweryfikować konto.'}), 201
    except mysql.connector.Error as err:
        if err.errno == 1062:  # Duplicate entry error
            return jsonify({'error': 'Taki użytkownik już istnieje'}), 409
        else:
            return jsonify({'error': str(err)}), 500

@app.route('/verify_email', methods=['GET'])
def verify_email():
    token = request.args.get('token')

    if not token:
        return jsonify({'error': 'Brak tokenu weryfikacyjnego'}), 400

    try:
        with mydb.cursor(dictionary=True) as cursor:
            # Weryfikacja tokenu i aktualizacja pola is_verified
            sql = "SELECT id FROM users WHERE verification_token = %s"
            cursor.execute(sql, (token,))
            user = cursor.fetchone()

            if not user:
                return jsonify({'error': 'Nieprawidłowy token weryfikacyjny'}), 400

            update_sql = "UPDATE users SET is_verified = 1, verification_token = NULL WHERE id = %s"
            cursor.execute(update_sql, (user[0],))
            mydb.commit()

        return jsonify({'message': 'E-mail został zweryfikowany pomyślnie'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        login = data['nickName']
        password = data['password']

        cursor = mydb.cursor(dictionary=True)
        sql = "SELECT * FROM users WHERE nickName = %s AND password = %s"
        val = (login, password)
        cursor.execute(sql, val)
        user = cursor.fetchone()

        if user:
            if user['is_verified'] == 0:
                return jsonify({'message': 'Adres e-mail nie został zweryfikowany'}), 403

            # Sprawdzanie, czy istnieje już token
            token = user.get('token')
            if not token:
                # Generowanie nowego tokenu, jeśli nie istnieje
                token = secrets.token_urlsafe(32)
                update_sql = "UPDATE users SET token = %s WHERE nickName = %s"
                cursor.execute(update_sql, (token, login))
                mydb.commit()
                print(f"Generated new token for user: {token}")
            else:
                print(f"Existing token found for user: {token}")

            return jsonify({'message': 'Zalogowano pomyślnie', 'user': user, 'token': token}), 200
        else:
            return jsonify({'message': 'Nieprawidłowy login lub hasło'}), 401
    except Exception as e:
        print(e)
        return jsonify({'error': str(e)}), 500


@app.route('/logout', methods=['POST'])
def logout():
    authorization_header = request.headers.get('Authorization')
    if not authorization_header or not authorization_header.startswith('Bearer '):
        return jsonify({'message': 'Brak lub niepoprawny token'}), 401

    token = authorization_header.split(' ')[1]
    cursor = mydb.cursor()
    sql = "UPDATE users SET token = NULL WHERE token = %s"
    cursor.execute(sql, (token,))
    mydb.commit()

    return jsonify({'message': 'Wylogowano pomyślnie'}), 200

# Sprawdzanei tokenu sesji + obsluga do zwrtoki id
@app.route('/verify_token', methods=['GET'])
def verify_token():
    try:
        # Upewnij się, że połączenie z bazą danych działa
        db = get_connection()
        cursor = db.cursor(dictionary=True)

        # Pobierz token z nagłówka
        authorization_header = request.headers.get('Authorization')
        if not authorization_header or not authorization_header.startswith("Bearer "):
            return jsonify({'error': 'Brak lub niepoprawny token'}), 401

        token = authorization_header.split(" ")[1]  # Usuń prefix "Bearer "

        # Wyszukaj użytkownika na podstawie tokenu
        sql = "SELECT id FROM users WHERE token = %s"
        cursor.execute(sql, (token,))
        user = cursor.fetchone()

        if user:
            print(f"DEBUG: User ID: {user['id']}")  # Loguj user_id
            return jsonify({'user_id': user['id']}), 200
        else:
            return jsonify({'error': 'Nieprawidłowy token'}), 401
    except mysql.connector.Error as e:
        print(f"MySQL Błąd: {e}")
        return jsonify({'error': 'Błąd bazy danych', 'details': str(e)}), 500
    except Exception as e:
        print(f"Ogólny błąd: {e}")
        return jsonify({'error': 'Błąd serwera', 'details': str(e)}), 500

# Filipa syfn a pobieranie hasła
@app.route('/get_password/<user_id>', methods=['GET'])
def get_password(user_id):
    try:
        cursor = mydb.cursor(dictionary=True)
        sql = "SELECT password FROM users WHERE id = %s"
        cursor.execute(sql, (user_id,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'error': 'Nie znaleziono użytkownika o podanym ID'}), 404

        return jsonify({'password': user['password']}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# Częśc patrykowa do konta użytkownika
@app.route('/get_user_by_token', methods=['POST'])
def get_user_by_token():
    try:
        # Pobranie danych z żądania
        data = request.get_json()
        token = data.get('token')

        if not token:
            return jsonify({"message": "Brak tokenu w żądaniu"}), 400

        # Połączenie z bazą danych
        with mydb.cursor(dictionary=True) as cursor:

            # Wykonanie zapytania SQL
            query = "SELECT id, email, nickName, imie, nazwisko, is_verified FROM users WHERE token = %s"
            cursor.execute(query, (token,))
            user = cursor.fetchone()

            # Zamknięcie kursora
            cursor.close()

            # Sprawdzenie, czy użytkownik istnieje
            if not user:
                return jsonify({"message": "Nie znaleziono użytkownika dla podanego tokenu"}), 404

        # Zwrócenie danych użytkownika
        return jsonify({"user": user}), 200

    except Exception as e:
        print(f"Błąd podczas pobierania danych użytkownika: {e}")
        return jsonify({"message": "Wystąpił błąd serwera"}), 500


@app.route('/update_user/<user_id>', methods=['PUT'])
def update_user(user_id):
    data = request.json  # Dane z ciała żądania
    update_fields = []

    # Budujemy zapytanie SQL na podstawie przesłanych pól
    for key, value in data.items():
        update_fields.append(f"{key} = %s")

    sql_query = f"UPDATE users SET {', '.join(update_fields)} WHERE id = %s"
    values = list(data.values()) + [user_id]

    try:
        # Używamy już istniejącego połączenia mydb
        cursor = mydb.cursor()
        cursor.execute(sql_query, values)
        mydb.commit()
        cursor.close()
        return jsonify({'message': 'Dane użytkownika zaktualizowane pomyślnie'}), 200
    except mysql.connector.Error as err:
        return jsonify({'message': f'Błąd bazy danych: {err}'}), 500
# ------------------- ZAPISYWANIE OBRAZU NA SERWER -------------------
@app.route('/upload_image', methods=['POST'])
def upload_image():
    if 'image' not in request.files:
        return jsonify({'error': 'Brak pliku w żądaniu'}), 400

    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'Nie wybrano pliku'}), 400

    # Zapisz plik w folderze 'uploads/'
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], file.filename)
    file.save(file_path)

    return jsonify({'message': 'Plik zapisany', 'file_path': file_path}), 200



@app.route('/uploads/<filename>')
def serve_image(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


# ------------------ WYSWIETLANIE WYDARZENIA Z BAZY -------------------
@app.route('/events', methods=['GET'])
def get_all_events():
    try:
        with mydb.cursor(dictionary=True) as cursor:
            sql = "SELECT * FROM events"
            cursor.execute(sql)
            events = cursor.fetchall()
            print(events)
            # Konwersja datetime na string
            for event in events:
                event['start_date'] = event['start_date'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify(events), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ------------------ DODAWANIE WYDARZENIA DO BAZY -------------------
@app.route('/events', methods=['POST'])
def add_event():
    try:
        data = request.get_json()
        with mydb.cursor() as cursor:
            sql = """
            INSERT INTO events (id, name, location, description, type, start_date, max_participants, registered_participants, image, user_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            val = (
                data['id'],
                data['name'],
                data['location'],
                data['description'],
                data['type'],
                data['start_date'],
                data['max_participants'],
                data['registered_participants'],
                data['image'],
                data['user_id']
            )
            cursor.execute(sql, val)
            mydb.commit()
        return jsonify({'message': 'Wydarzenie dodane pomyślnie'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ------------------------ AKTUALIZOWANIE WYDARZEN W BAZIE ------------------------
@app.route('/events/<event_id>', methods=['PUT'])
def update_event(event_id):
    try:
        data = request.get_json()
        cursor = mydb.cursor()
        sql = """
        UPDATE events
        SET name = %s, location = %s, description = %s, type = %s, start_date = %s, max_participants = %s, registered_participants = %s, image = %s
        WHERE id = %s
        """
        val = (
            data['name'],
            data['location'],
            data['description'],
            data['type'],
            data['start_date'],
            data['max_participants'],
            data['registered_participants'],
            data['image'],
            event_id
        )
        cursor.execute(sql, val)
        mydb.commit()
        return jsonify({'message': 'Wydarzenie zaktualizowane pomyślnie'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/events/<event_id>', methods=['DELETE'])
def delete_event(event_id):
    try:
        cursor = mydb.cursor()
        sql = "DELETE FROM events WHERE id = %s"
        cursor.execute(sql, (event_id,))
        mydb.commit()
        return jsonify({'message': 'Wydarzenie usunięte pomyślnie'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/events/<event_id>/join', methods=['POST'])
def join_event(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu lub niepoprawny token'}), 401

        token = token.split(" ")[1]
        cursor = mydb.cursor(dictionary=True)

        # Pobieranie user_id z tokenu
        sql = "SELECT id FROM users WHERE token = %s"
        cursor.execute(sql, (token,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        user_id = user['id']

        # Sprawdzenie, czy użytkownik jest już zapisany na wydarzenie
        sql_check = "SELECT * FROM event_participants WHERE event_id = %s AND user_id = %s"
        cursor.execute(sql_check, (event_id, user_id))
        result = cursor.fetchone()
        if result:
            return jsonify({'error': 'Użytkownik jest już zapisany na to wydarzenie'}), 400

        # Zapis użytkownika na wydarzenie
        sql_insert = "INSERT INTO event_participants (event_id, user_id) VALUES (%s, %s)"
        cursor.execute(sql_insert, (event_id, user_id))
        
        # Aktualizacja liczby uczestników
        sql_update_participants = """
        UPDATE events
        SET registered_participants = registered_participants + 1
        WHERE id = %s
        """
        cursor.execute(sql_update_participants, (event_id,))
        
        mydb.commit()

        return jsonify({'message': 'Zapisano użytkownika na wydarzenie'}), 200
    except Exception as e:
        print(f"Błąd: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/events/<event_id>/leave', methods=['POST'])
def leave_event(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu lub niepoprawny token'}), 401

        token = token.split(" ")[1]
        cursor = mydb.cursor(dictionary=True)

        # Pobieranie user_id z tokenu
        sql = "SELECT id FROM users WHERE token = %s"
        cursor.execute(sql, (token,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        user_id = user['id']

        # Usuwanie użytkownika z wydarzenia
        sql_delete = "DELETE FROM event_participants WHERE event_id = %s AND user_id = %s"
        cursor.execute(sql_delete, (event_id, user_id))
        
        # Aktualizacja liczby uczestników
        sql_update_participants = """
        UPDATE events
        SET registered_participants = registered_participants - 1
        WHERE id = %s
        """
        cursor.execute(sql_update_participants, (event_id,))
        
        mydb.commit()

        return jsonify({'message': 'Użytkownik został wypisany z wydarzenia'}), 200
    except Exception as e:
        print(f"Błąd: {e}")
        return jsonify({'error': str(e)}), 500
# Czy user jest zapisany na wydarzenie
@app.route('/events/<event_id>/check', methods=['GET'])
def check_user_joined(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu lub niepoprawny token'}), 401

        token = token.split(" ")[1]
        with mydb.cursor(dictionary=True) as cursor:

            # Pobieranie user_id z tokenu
            sql = "SELECT id FROM users WHERE token = %s"
            cursor.execute(sql, (token,))
            user = cursor.fetchone()

            if not user:
                return jsonify({'error': 'Nieprawidłowy token'}), 401

            user_id = user['id']

            # Sprawdzenie, czy użytkownik jest zapisany na wydarzenie
            sql_check = "SELECT * FROM event_participants WHERE event_id = %s AND user_id = %s"
            cursor.execute(sql_check, (event_id, user_id))
            is_joined = cursor.fetchone() is not None

        return jsonify({'is_joined': is_joined}), 200
    except Exception as e:
        print(f"Błąd: {e}")
        return jsonify({'error': str(e)}), 500

# Czy jest moderatorem danego wydarzenia 
@app.route('/events/<event_id>/is_admin', methods=['GET'])
def is_admin(event_id):
    try:
        # Pobierz token z nagłówka
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu lub niepoprawny token'}), 401

        # Usuń prefix "Bearer "
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)

        # Pobierz user_id na podstawie tokenu
        sql_get_user = "SELECT id FROM users WHERE token = %s"
        cursor.execute(sql_get_user, (token,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        user_id = user['id']
        print(f"DEBUG: user_id={user_id}, event_id={event_id}")

        # Sprawdź, czy user_id jest administratorem wydarzenia
        sql_check_admin = "SELECT * FROM events WHERE id = %s AND user_id = %s"
        cursor.execute(sql_check_admin, (event_id, user_id))
        is_admin = cursor.fetchone() is not None
        print(f"DEBUG: is_admin={is_admin}")

        return jsonify({'is_admin': is_admin}), 200
    except Exception as e:
        print(f"Błąd: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/delete_account', methods=['DELETE'])
def delete_account():
    token = request.headers.get('Authorization')
    if token:
        token = token.split(" ")[1]  # Usuń prefix "Bearer "
        cursor = mydb.cursor()

        # Pobierz użytkownika na podstawie tokenu
        sql_select = "SELECT id FROM users WHERE token = %s"
        cursor.execute(sql_select, (token,))
        user = cursor.fetchone()

        if user:
            user_id = user[0]
            sql_delete = "DELETE FROM users WHERE id = %s"
            cursor.execute(sql_delete, (user_id,))
            mydb.commit()
            return jsonify({'message': 'Konto zostało usunięte'}), 200
        else:
            return jsonify({'error': 'Nieprawidłowy token'}), 401
    else:
        return jsonify({'error': 'Brak tokenu'}), 401

@app.route('/change_password', methods=['POST'])
def change_password():
    try:
        data = request.get_json()
        email = data['email']
        new_password = data['new_password']

        cursor = mydb.cursor()
        sql_check = "SELECT id FROM users WHERE email = %s"
        cursor.execute(sql_check, (email,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'error': 'Użytkownik o podanym emailu nie istnieje'}), 404

        sql_update = "UPDATE users SET password = %s WHERE email = %s"
        cursor.execute(sql_update, (new_password, email))
        mydb.commit()

        return jsonify({'message': 'Hasło zostało zmienione'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/change_password_with_old', methods=['POST'])
def change_password_with_old():
    try:
        data = request.get_json()
        old_password = data['password']
        new_password = data['new_password']

        cursor = mydb.cursor()
        sql_check = "SELECT id FROM users WHERE password = %s"
        cursor.execute(sql_check, (old_password,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'error': 'Użytkownik o podanym haśle nie istnieje'}), 404

        sql_update = "UPDATE users SET password = %s WHERE password = %s"
        cursor.execute(sql_update, (new_password, old_password))
        mydb.commit()

        return jsonify({'message': 'Hasło zostało zmienione'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/verify_password', methods=['POST'])
def verify_password():
    try:
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Brak tokenu'}), 401

        token = token.split(" ")[1]  # Usuń prefix "Bearer "
        data = request.get_json()
        password = data['password']

        cursor = mydb.cursor(dictionary=True)
        sql = "SELECT password FROM users WHERE token = %s"
        cursor.execute(sql, (token,))
        user = cursor.fetchone()

        if not user or user['password'] != password:
            return jsonify({'error': 'Nieprawidłowe hasło'}), 401

        return jsonify({'message': 'Hasło poprawne'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    ip = get_local_ip()
    app.run(host=f'{ip}', port=5000, debug=True)
