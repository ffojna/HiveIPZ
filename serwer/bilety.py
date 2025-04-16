import smtplib
from email.mime.text import MIMEText
from flask import Flask, request, jsonify, send_from_directory, redirect, session
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import secrets
from dotenv import load_dotenv
import os
from datetime import datetime
import base64
import socket
import re # Obsługa regexa
from datetime import timedelta # Obsługa czasu niekatywnosci
import json
from google.oauth2 import id_token
from google.auth.transport import requests as grequests
from requests_oauthlib import OAuth1Session


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


# Konfiguracja połączenia z Twitter
app.secret_key = secrets.token_hex(16) 

REQUEST_TOKEN_URL = "https://api.twitter.com/oauth/request_token"
AUTHORIZATION_URL = "https://api.twitter.com/oauth/authorize"
ACCESS_TOKEN_URL = "https://api.twitter.com/oauth/access_token"
VERIFY_CREDENTIALS_URL = "https://api.twitter.com/1.1/account/verify_credentials.json"


@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        imie = data['name']
        nazwisko = data['surname']
        wiek = data['age']
        nickname = data['nickName']
        email = data['email']
        password = data['password']

        # if wiek < 16:
        #     return jsonify({'error': 'Minimalny wiek to 16 lat'}), 400

        cursor = mydb.cursor()
        # Generowanie unikalnego tokenu weryfikacyjnego
        verification_token = secrets.token_urlsafe(32)

        sql = """
        INSERT INTO users (nickName, imie, nazwisko, wiek, email, password, is_verified, verification_token)
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
        cursor = mydb.cursor()
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
    data = request.get_json()
    login_input = data.get('nickName')
    password = data.get('password')

    print(f"\n[REQUEST_DATA] Login: {login_input}, Hasło: {password}")  # Logowanie danych

    if not login_input or not password:
        return jsonify({'message': 'Brak loginu lub hasła'}), 400

    email_pattern = r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
    is_email = re.match(email_pattern, login_input) is not None

    try:
        cursor = mydb.cursor(dictionary=True)
        column = 'email' if is_email else 'nickName'

        # Pobierz użytkownika z bazy
        sql = f"SELECT * FROM users WHERE {column} = %s"
        cursor.execute(sql, (login_input,))
        user = cursor.fetchone()

        if not user or user['password'] != password:
            return jsonify({'message': 'Nieprawidłowy login lub hasło'}), 401


        if not user['is_verified']:
            return jsonify({'message': 'Konto niezweryfikowane'}), 403

        token = user.get('token')
        if not token:
            token = secrets.token_urlsafe(32)
            update_sql = f"UPDATE users SET token = %s WHERE {column} = %s"
            cursor.execute(update_sql, (token, login_input))
            mydb.commit()

        user_id = user['id']
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        expires_at = (datetime.now() + timedelta(days=120)).strftime('%Y-%m-%d %H:%M:%S')  # Wygaśnięcie za 120 dni

        # Sprawdź, czy rekord istnieje w users_info
        check_sql = "SELECT userID FROM users_info WHERE userID = %s"
        cursor.execute(check_sql, (user_id,))
        existing_record = cursor.fetchone()

        if existing_record:
            # Jeżeli taki rekord instieje, aktualizuuemy go
            update_info_sql = """
                        UPDATE users_info 
                        SET last_login = %s, token_expires_at = %s 
                        WHERE userID = %s
                    """
            cursor.execute(update_info_sql, (current_time, expires_at, user_id))
        else:
            # Jeżeli go nie ma ^ tworzymy
            insert_info_sql = """
                        INSERT INTO users_info (userID, last_login, token_expires_at) 
                        VALUES (%s, %s, %s)
                    """
            cursor.execute(insert_info_sql, (user_id, current_time, expires_at))

        mydb.commit()

        return jsonify({
            'message': 'Zalogowano pomyślnie',
            'user': {
                'id': user['id'],
                'email': user['email'],
                'nickName': user['nickName'],
                'is_verified': user['is_verified']
            },
            'token': token
        }), 200


    except Exception as e:
        print(f"[SERVER_ERROR] {str(e)}")  # Logowanie błędów serwera
        return jsonify({'message': f'Błąd serwera: {str(e)}'}), 500

@app.route('/google_login', methods=['POST'])
def google_login():
    try:
        data = request.get_json()
        id_token_str = data.get('id_token')

        if not id_token_str:
            return jsonify({'error': 'Brak tokenu'}), 400

        # Weryfikacja tokenu z Google
        idinfo = id_token.verify_oauth2_token(id_token_str, grequests.Request())

        email = idinfo['email']
        name = idinfo.get('name', '')
        nickname = email.split('@')[0]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()

        if not user:
            # Rejestracja nowego użytkownika
            cursor.execute("""
                INSERT INTO users (nickName, imie, nazwisko, wiek, email, password, is_verified)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (nickname, name, '', 18, email, '', 1))
            mydb.commit()

            cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
            user = cursor.fetchone()

        # Wygenerowanie i zapis tokenu
        token = secrets.token_urlsafe(32)
        cursor.execute("UPDATE users SET token = %s WHERE email = %s", (token, email))
        mydb.commit()

        return jsonify({
            'message': 'Zalogowano przez Google',
            'user': {
                'id': user['id'],
                'email': user['email'],
                'nickName': user['nickName']
            },
            'token': token
        }), 200
    except ValueError:
        return jsonify({'error': 'Nieprawidłowy token Google'}), 401
    except Exception as e:
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





@app.route('/update_user/<user_id>', methods=['PUT'])
def update_user(user_id):
    data = request.json
    update_fields = []
    values = []

    for key, value in data.items():
        if isinstance(value, list):
            value = json.dumps(value)  # Zamień listę na JSON
        update_fields.append(f"{key} = %s")
        values.append(value)

    sql_query = f"UPDATE users SET {', '.join(update_fields)} WHERE id = %s"
    values.append(user_id)

    try:
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
        cursor = mydb.cursor(dictionary=True)
        sql = "SELECT * FROM events"
        cursor.execute(sql)
        events = cursor.fetchall()
        print(events)
        
        # Konwersja wszystkich datetime na string i decimal na float
        for event in events:
            if 'start_date' in event and event['start_date']:
                event['start_date'] = event['start_date'].strftime('%Y-%m-%d %H:%M:%S')
            
            # Konwersja decimals na float dla JSON serialization
            if 'cena' in event and event['cena'] is not None:
                event['cena'] = float(event['cena'])

        return jsonify(events), 200
    except Exception as e:
        print(f"Error in get_all_events: {e}")
        return jsonify({'error': str(e)}), 500

# ------------------ DODAWANIE WYDARZENIA DO BAZY -------------------
@app.route('/events', methods=['POST'])
def add_event():
    try:
        data = request.get_json()
        cursor = mydb.cursor()
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
        SET name = %s, location = %s, description = %s, type = %s, start_date = %s, max_participants = %s, registered_participants = %s, image = %s, is_promoted = %s
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
            data['is_promoted'],
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

        # Sprawdzenie, czy użytkownik jest zbanowany
        sql_check_ban = "SELECT * FROM event_bans WHERE event_id = %s AND user_id = %s"
        cursor.execute(sql_check_ban, (event_id, user_id))
        if cursor.fetchone():
            return jsonify({'error': 'Użytkownik jest zbanowany i nie może dołączyć do tego wydarzenia'}), 403

        # Sprawdzenie, czy użytkownik jest już zapisany na wydarzenie
        sql_check = "SELECT * FROM event_participants WHERE event_id = %s AND user_id = %s"
        cursor.execute(sql_check, (event_id, user_id))
        if cursor.fetchone():
            return jsonify({'error': 'Użytkownik jest już zapisany na to wydarzenie'}), 400

        # Generowanie niepowtarzalnego kodu biletu
        ticket_number = secrets.token_urlsafe(16)
        
        # Sprawdzenie czy kolumna ticket_number istnieje w tabeli event_participants
        try:
            # Pobranie informacji o wydarzeniu
            sql_event = "SELECT cena FROM events WHERE id = %s"
            cursor.execute(sql_event, (event_id,))
            event = cursor.fetchone()
            ticket_price = event.get('cena', 0.00) if event else 0.00
            
            # Zapis biletu w bazie danych
            ticket_id = secrets.token_urlsafe(8)
            purchase_date = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            # Dodanie biletu do tabeli tickets
            sql_insert_ticket = """
            INSERT INTO tickets (id, user_id, event_id, purchase_date, status, price)
            VALUES (%s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql_insert_ticket, (
                ticket_id, 
                user_id, 
                event_id, 
                purchase_date, 
                'active', 
                ticket_price
            ))
            
            # Próba zapisu użytkownika z numerem biletu
            try:
                sql_insert = "INSERT INTO event_participants (event_id, user_id, ticket_number) VALUES (%s, %s, %s)"
                cursor.execute(sql_insert, (event_id, user_id, ticket_number))
            except mysql.connector.Error as err:
                # Jeśli kolumna nie istnieje, próbujemy bez niej
                if err.errno == 1054:  # Błąd "Unknown column"
                    sql_insert = "INSERT INTO event_participants (event_id, user_id) VALUES (%s, %s)"
                    cursor.execute(sql_insert, (event_id, user_id))
                    print(f"Kolumna ticket_number nie istnieje w tabeli event_participants: {err}")
                else:
                    raise err

            # Aktualizacja liczby uczestników
            sql_update_participants = """
            UPDATE events
            SET registered_participants = registered_participants + 1
            WHERE id = %s
            """
            cursor.execute(sql_update_participants, (event_id,))

            mydb.commit()

            return jsonify({
                'message': 'Zapisano użytkownika na wydarzenie',
                'ticket_number': ticket_number
            }), 200
        except Exception as e:
            mydb.rollback()  # Cofamy zmiany w przypadku błędu
            print(f"Błąd podczas dołączania do wydarzenia: {e}")
            raise e
            
    except Exception as e:
        print(f"Błąd: {e}")
        return jsonify({'error': str(e)}), 500

# Częśc patrykowa do konta użytkownika
@app.route('/get_user_by_token', methods=['POST'])
def get_user_by_token():
    try:
        data = request.get_json()
        token = data.get('token')

        if not token:
            return jsonify({"message": "Brak tokenu w żądaniu"}), 400

        cursor = mydb.cursor(dictionary=True)
        query = """
            SELECT id, email, nickName, imie, nazwisko, is_verified, points, recent_searches 
            FROM users WHERE token = %s
        """
        cursor.execute(query, (token,))
        user = cursor.fetchone()
        cursor.close()

        if not user:
            return jsonify({"message": "Nie znaleziono użytkownika dla podanego tokenu"}), 404

        # Przekształcenie recent_searches z JSON na listę
        if user.get("recent_searches"):
            try:
                user["recent_searches"] = json.loads(user["recent_searches"])
            except:
                user["recent_searches"] = []
        else:
            user["recent_searches"] = []

        return jsonify({"user": user}), 200

    except Exception as e:
        print(f"Błąd podczas pobierania danych użytkownika: {e}")
        return jsonify({"message": "Wystąpił błąd serwera"}), 500


@app.route('/get_recent_searches', methods=['GET'])
def get_recent_searches():
    token = request.headers.get('Authorization')
    if not token or not token.startswith("Bearer "):
        return jsonify({'error': 'Brak tokenu'}), 401
    token = token.split(" ")[1]

    cursor = mydb.cursor(dictionary=True)
    sql = "SELECT recent_searches FROM users WHERE token = %s"
    cursor.execute(sql, (token,))
    user = cursor.fetchone()
    if not user:
        return jsonify({'error': 'Nie znaleziono użytkownika'}), 404

    try:
        searches = json.loads(user['recent_searches']) if user['recent_searches'] else []
        return jsonify({'recent_searches': searches}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/update_recent_searches', methods=['POST'])
def update_recent_searches():
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu lub niepoprawny token'}), 401

        token = token.split(" ")[1]
        data = request.get_json()
        recent_searches = data.get('recent_searches')

        if not isinstance(recent_searches, list):
            return jsonify({'error': 'recent_searches musi być listą'}), 400

        cursor = mydb.cursor()
        sql = "UPDATE users SET recent_searches = %s WHERE token = %s"
        cursor.execute(sql, (json.dumps(recent_searches), token))
        mydb.commit()
        cursor.close()

        return jsonify({'message': 'recentSearches zaktualizowane pomyślnie'}), 200

    except Exception as e:
        print(f"Błąd podczas aktualizacji recentSearches: {e}")
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
        cursor = mydb.cursor(dictionary=True)

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


@app.route('/user_events', methods=['GET'])
def get_user_events():
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

        # Pobieranie wydarzeń powiązanych z user_id
        sql_events = "SELECT * FROM events WHERE user_id = %s"
        cursor.execute(sql_events, (user_id,))
        events = cursor.fetchall()

        # Konwersja obiektów datetime na string i decimal na float dla serializacji JSON
        for event in events:
            if 'start_date' in event and event['start_date']:
                event['start_date'] = event['start_date'].strftime('%Y-%m-%d %H:%M:%S')
            
            # Konwersja decimals na float dla JSON serialization
            if 'cena' in event and event['cena'] is not None:
                event['cena'] = float(event['cena'])

        return jsonify(events), 200
    except Exception as e:
        print(f"Błąd podczas pobierania wydarzeń administrowanych: {e}")
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

@app.route('/')
def mainPage():
   return "Ahoj"

@app.route('/events/<event_id>/participants', methods=['GET'])
def get_event_participants(event_id):
    try:
        cursor = mydb.cursor(dictionary=True)
        sql = """
        SELECT users.nickName FROM event_participants
        JOIN users ON event_participants.user_id = users.id
        WHERE event_participants.event_id = %s
        """
        cursor.execute(sql, (event_id,))
        participants = cursor.fetchall()

        return jsonify(participants), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/get_user_preferences', methods=['GET'])
def get_user_preferences():
    user_id = request.args.get('user_id')

    cursor = mydb.cursor(dictionary=True)
    cursor.execute("SELECT has_set_preferences FROM users WHERE id = %s", (user_id,))
    result = cursor.fetchone()

    if result is None:
        return jsonify({'error': 'Użytkownik nie istnieje'}), 404

    return jsonify({'hasSetPreferences': result['has_set_preferences']}), 200


@app.route('/set_user_preferences', methods=['POST'])
def set_user_preferences():
    data = request.get_json()
    user_id = data.get('user_id')

    cursor = mydb.cursor()
    cursor.execute("UPDATE users SET has_set_preferences = TRUE WHERE id = %s", (user_id,))
    mydb.commit()

    return jsonify({'message': 'Preferencje zapisane'}), 200

@app.route('/user_event_preferences', methods=['GET'])
def get_user_event_preferences():
    user_id = request.args.get('user_id')
    cursor = mydb.cursor(dictionary=True)
    cursor.execute("SELECT event_type FROM user_event_preferences WHERE user_id = %s", (user_id,))
    preferences = [row['event_type'] for row in cursor.fetchall()]
    return jsonify({'preferences': preferences}), 200

@app.route('/user_event_preferences', methods=['POST'])
def set_user_event_preferences():
    data = request.get_json()
    user_id = data['user_id']
    selected_types = data['event_types']

    cursor = mydb.cursor()

    cursor.execute("DELETE FROM user_event_preferences WHERE user_id = %s", (user_id,))
    
    for event_type in selected_types:
        cursor.execute("INSERT INTO user_event_preferences (user_id, event_type) VALUES (%s, %s)", (user_id, event_type))

    mydb.commit()
    return jsonify({'message': 'Preferencje zaktualizowane'}), 200

@app.route('/events/<event_id>/ban', methods=['POST'])
def ban_user(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu lub niepoprawny token'}), 401

        token = token.split(" ")[1]
        cursor = mydb.cursor(dictionary=True)

        # Pobieranie user_id z tokenu
        sql_get_admin = "SELECT id FROM users WHERE token = %s"
        cursor.execute(sql_get_admin, (token,))
        admin_user = cursor.fetchone()

        if not admin_user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        admin_id = admin_user['id']

        # Sprawdzenie, czy użytkownik jest administratorem wydarzenia
        sql_check_admin = "SELECT * FROM events WHERE id = %s AND user_id = %s"
        cursor.execute(sql_check_admin, (event_id, admin_id))
        if not cursor.fetchone():
            return jsonify({'error': 'Brak uprawnień do zarządzania wydarzeniem'}), 403

        # Pobranie nickName użytkownika do zbanowania
        data = request.get_json()
        banned_nick = data.get('nickName')

        if not banned_nick:
            return jsonify({'error': 'Brak nickName w żądaniu'}), 400

        # Zamiana nickName na user_id
        sql_get_user_id = "SELECT id FROM users WHERE nickName = %s"
        cursor.execute(sql_get_user_id, (banned_nick,))
        banned_user = cursor.fetchone()

        if not banned_user:
            return jsonify({'error': 'Nie znaleziono użytkownika o takim nickName'}), 404

        banned_user_id = banned_user['id']

        # Sprawdzenie, czy użytkownik jest już zbanowany
        sql_check_ban = "SELECT * FROM event_bans WHERE event_id = %s AND user_id = %s"
        cursor.execute(sql_check_ban, (event_id, banned_user_id))
        if cursor.fetchone():
            return jsonify({'message': 'Użytkownik jest już zbanowany'}), 200

        # Usunięcie użytkownika z wydarzenia (jeśli jest zapisany)
        sql_remove_participant = "DELETE FROM event_participants WHERE event_id = %s AND user_id = %s"
        cursor.execute(sql_remove_participant, (event_id, banned_user_id))

        # Zaktualizowanie kolumny registered_participants w tabeli events
        sql_update_participants = """
            UPDATE events
            SET registered_participants = registered_participants - 1
            WHERE id = %s
        """
        cursor.execute(sql_update_participants, (event_id,))

        # Dodanie użytkownika do listy zbanowanych
        sql_ban_user = "INSERT INTO event_bans (event_id, user_id) VALUES (%s, %s)"
        cursor.execute(sql_ban_user, (event_id, banned_user_id))
        mydb.commit()


        return jsonify({'message': 'Użytkownik został zbanowany i usunięty z wydarzenia'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/events/<int:user_id>', methods=['GET'])
def get_users_events(user_id):
    try:
        cursor = mydb.cursor(dictionary=True)
        sql = "SELECT * FROM events WHERE user_id = %s"
        cursor.execute(sql, (user_id,))
        events = cursor.fetchall()

        # Konwersja wszystkich datetime na string i decimal na float
        for event in events:
            if 'start_date' in event and event['start_date']:
                event['start_date'] = event['start_date'].strftime('%Y-%m-%d %H:%M:%S')
            
            # Konwersja decimals na float dla JSON serialization
            if 'cena' in event and event['cena'] is not None:
                event['cena'] = float(event['cena'])
                
            # Dodatkowe konwersje
            if 'score' in event and event['score'] is not None:
                event['score'] = int(event['score'])
                
            if 'is_promoted' in event:
                event['is_promoted'] = bool(event['is_promoted'])

        return jsonify(events), 200
    except Exception as e:
        print(f"Error in get_users_events: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/joined_events', methods=['GET'])
def get_joined_events():
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401

        token = token.split(" ")[1]
        cursor = mydb.cursor(dictionary=True)

        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        user_id = user['id']

        sql = """
        SELECT e.* FROM events e
        JOIN event_participants ep ON e.id = ep.event_id
        WHERE ep.user_id = %s AND e.user_id != %s
        """
        cursor.execute(sql, (user_id, user_id))

        events = cursor.fetchall()

        # Konwersja obiektów datetime na string i decimal na float dla serializacji JSON
        for event in events:
            if 'start_date' in event and event['start_date']:
                event['start_date'] = event['start_date'].strftime('%Y-%m-%d %H:%M:%S')
            
            # Konwersja decimals na float dla JSON serialization
            if 'cena' in event and event['cena'] is not None:
                event['cena'] = float(event['cena'])
                
            # Dodatkowe typowe konwersje
            if 'score' in event and event['score'] is not None:
                event['score'] = int(event['score'])
                
            if 'is_promoted' in event:
                # Konwersja wartości is_promoted na bool
                event['is_promoted'] = bool(event['is_promoted'])

        return jsonify(events), 200
    except Exception as e:
        print(f"Błąd podczas pobierania dołączonych wydarzeń: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/events/<event_id>/banned_users', methods=['GET'])
def get_banned_users(event_id):
    try:
        cursor = mydb.cursor(dictionary=True)
        sql = """
        SELECT u.nickName FROM event_bans b
        JOIN users u ON b.user_id = u.id
        WHERE b.event_id = %s
        """
        cursor.execute(sql, (event_id,))
        banned = cursor.fetchall()
        return jsonify([row['nickName'] for row in banned]), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500



@app.route('/events/<event_id>/unban', methods=['POST'])
def unban_user(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401

        token = token.split(" ")[1]
        cursor = mydb.cursor(dictionary=True)

        # Pobierz ID admina
        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        admin = cursor.fetchone()
        if not admin:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        admin_id = admin['id']

        # Sprawdź czy user to właściciel eventu
        cursor.execute("SELECT * FROM events WHERE id = %s AND user_id = %s", (event_id, admin_id))
        if not cursor.fetchone():
            return jsonify({'error': 'Brak uprawnień do odbanowania'}), 403

        # Pobierz nickName do odbanowania
        data = request.get_json()
        nick = data.get('nickName')
        if not nick:
            return jsonify({'error': 'Brak nickName'}), 400

        cursor.execute("SELECT id FROM users WHERE nickName = %s", (nick,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nie znaleziono użytkownika'}), 404

        user_id = user['id']

        cursor.execute("DELETE FROM event_bans WHERE event_id = %s AND user_id = %s", (event_id, user_id))
        mydb.commit()

        return jsonify({'message': 'Użytkownik został odbanowany'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    

@app.route('/report_event', methods=['POST'])
def report_event():
    try:
        data = request.get_json()
        event_id = data['event_id']
        reason = data['reason']

        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu lub niepoprawny token'}), 401
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        user_id = user['id']
        cursor.execute("INSERT INTO event_reports (event_id, reason, user_id) VALUES (%s, %s, %s)", (event_id, reason, user_id))
        mydb.commit()
        return jsonify({'message': 'Zgłoszenie zostało zapisane'}), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/rate_organizer', methods=['POST'])
def rate_organizer():
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        data = request.get_json()
        organizer_id = data.get("organizer_id")
        rating = int(data.get("rating"))

        if not (1 <= rating <= 5):
            return jsonify({'error': 'Ocena musi być w zakresie 1–5'}), 400

        cursor.execute("""
            INSERT INTO organizer_ratings (organizer_id, rated_by_user_id, rating)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE rating = %s
        """, (organizer_id, user["id"], rating, rating))
        mydb.commit()

        return jsonify({'message': 'Ocena zapisana'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/organizer/<int:organizer_id>/rating', methods=['GET'])
def get_organizer_rating(organizer_id):
    try:
        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT ROUND(AVG(rating), 2) AS avg_rating FROM organizer_ratings WHERE organizer_id = %s", (organizer_id,))
        result = cursor.fetchone()
        
        # Bezpieczna obsługa przypadku braku ocen (NULL)
        if result is None or result['avg_rating'] is None:
            avg = 0.0
        else:
            try:
                avg = float(result['avg_rating'])
            except (ValueError, TypeError):
                avg = 0.0
                
        return jsonify({'average_rating': avg}), 200
    except Exception as e:
        print(f"Error in get_organizer_rating: {e}")
        return jsonify({'error': str(e), 'average_rating': 0.0}), 500



@app.route('/has_rated/<int:organizer_id>', methods=['GET'])
def has_rated(organizer_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        cursor.execute("""
            SELECT COUNT(*) AS total FROM organizer_ratings
            WHERE organizer_id = %s AND rated_by_user_id = %s
        """, (organizer_id, user['id']))
        result = cursor.fetchone()

        return jsonify({'hasRated': result['total'] > 0}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
    
@app.route('/twitter/login')
def twitter_login():
    twitter = OAuth1Session(
        os.getenv("TWITTER_API_KEY"),
        client_secret=os.getenv("TWITTER_API_SECRET"),
        callback_uri=os.getenv("TWITTER_CALLBACK_URL")
    )

    fetch_response = twitter.fetch_request_token(REQUEST_TOKEN_URL)
    session['oauth_token'] = fetch_response.get('oauth_token')
    session['oauth_token_secret'] = fetch_response.get('oauth_token_secret')

    authorization_url = twitter.authorization_url(AUTHORIZATION_URL)
    return redirect(authorization_url)

@app.route('/twitter/callback')
def twitter_callback():
    oauth_token = request.args.get('oauth_token')
    oauth_verifier = request.args.get('oauth_verifier')

    twitter = OAuth1Session(
        os.getenv("TWITTER_API_KEY"),
        client_secret=os.getenv("TWITTER_API_SECRET"),
        resource_owner_key=session['oauth_token'],
        resource_owner_secret=session['oauth_token_secret'],
        verifier=oauth_verifier,
    )

    oauth_tokens = twitter.fetch_access_token(ACCESS_TOKEN_URL)
    access_token = oauth_tokens['oauth_token']
    access_token_secret = oauth_tokens['oauth_token_secret']

    # Pobierz dane użytkownika z Twittera
    twitter = OAuth1Session(
        os.getenv("TWITTER_API_KEY"),
        client_secret=os.getenv("TWITTER_API_SECRET"),
        resource_owner_key=access_token,
        resource_owner_secret=access_token_secret
    )
    response = twitter.get(VERIFY_CREDENTIALS_URL)
    profile = response.json()

    twitter_id = profile['id_str']
    screen_name = profile['screen_name']
    name = profile.get('name', '')
    email = profile.get('email', '')  # tylko jeśli masz dostęp

    # TODO: sprawdź w bazie czy istnieje, jak nie to utwórz
    # Potem zwróć token lub przekieruj do frontu
    return jsonify({
        'id': twitter_id,
        'nick': screen_name,
        'name': name
    })

@app.route('/events/<event_id>/rate', methods=['POST'])
def rate_event(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        user_id = user['id']
        data = request.get_json()
        rate_type = data.get("type")  # "like" lub "dislike"

        if rate_type not in ("like", "dislike"):
            return jsonify({'error': 'Nieprawidłowy typ oceny'}), 400

        # Sprawdź czy user już ocenił
        cursor.execute("SELECT type FROM event_likes WHERE user_id = %s AND event_id = %s", (user_id, event_id))
        existing = cursor.fetchone()

        score_change = 0

        if existing:
            if existing['type'] == rate_type:
                return jsonify({'message': 'Już ocenione'}), 200
            # Cofamy poprzednią ocenę
            if existing['type'] == 'like' and rate_type == 'dislike':
                score_change = -2
            elif existing['type'] == 'dislike' and rate_type == 'like':
                score_change = 2
            cursor.execute("UPDATE event_likes SET type = %s WHERE user_id = %s AND event_id = %s",
                           (rate_type, user_id, event_id))
        else:
            score_change = 1 if rate_type == 'like' else -1
            cursor.execute("INSERT INTO event_likes (user_id, event_id, type) VALUES (%s, %s, %s)",
                           (user_id, event_id, rate_type))

        # Aktualizuj score w tabeli events
        cursor.execute("UPDATE events SET score = score + %s WHERE id = %s", (score_change, event_id))
        mydb.commit()

        return jsonify({'message': 'Ocena zapisana'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500



@app.route('/events/<event_id>/rating_status', methods=['GET'])
def get_event_rating_status(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        user_id = user['id']

        # Ocena użytkownika
        cursor.execute("SELECT type FROM event_likes WHERE user_id = %s AND event_id = %s", (user_id, event_id))
        row = cursor.fetchone()
        rating = row['type'] if row else None

        # Score wydarzenia
        cursor.execute("SELECT score FROM events WHERE id = %s", (event_id,))
        score_row = cursor.fetchone()
        score = score_row['score'] if score_row else 0

        return jsonify({'rating': rating, 'score': score}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500



@app.route('/events/<event_id>/comments', methods=['POST'])
def add_comment(event_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT id, nickName FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        data = request.get_json()
        content = data.get("text")

        if not content or len(content.strip()) == 0:
            return jsonify({'error': 'Komentarz nie może być pusty'}), 400

        cursor.execute("""
            INSERT INTO event_comments (event_id, user_id, content, created_at)
            VALUES (%s, %s, %s, NOW())
        """, (event_id, user['id'], content))
        mydb.commit()

        return jsonify({'message': 'Komentarz dodany'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/events/<event_id>/comments', methods=['GET'])
def get_comments(event_id):
    try:
        cursor = mydb.cursor(dictionary=True)
        cursor.execute("""
            SELECT c.id, c.user_id, u.nickName AS username, c.content AS text, c.created_at
            FROM event_comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.event_id = %s
            ORDER BY c.created_at DESC
        """, (event_id,))
        comments = cursor.fetchall()

        return jsonify(comments), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/events/<event_id>/comments/<comment_id>/report', methods=['POST'])
def report_comment(event_id, comment_id):
    try:
        token = request.headers.get('Authorization')
        if not token or not token.startswith("Bearer "):
            return jsonify({'error': 'Brak tokenu'}), 401
        token = token.split(" ")[1]

        cursor = mydb.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE token = %s", (token,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'error': 'Nieprawidłowy token'}), 401

        data = request.get_json()
        reason = data.get("reason")

        cursor.execute("""
            INSERT INTO comment_reports (comment_id, event_id, user_id, reason, reported_at)
            VALUES (%s, %s, %s, %s, NOW())
        """, (comment_id, event_id, user['id'], reason))
        mydb.commit()

        return jsonify({'message': 'Komentarz zgłoszony'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/user/tickets', methods=['GET'])
def get_user_tickets():
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

        # Pobieranie biletów wraz z informacjami o wydarzeniach
        sql_tickets = """
        SELECT 
            t.id as ticket_id, 
            t.status, 
            t.price,
            t.purchase_date,
            e.id as event_id, 
            e.name as event_name, 
            e.location as event_location,
            e.start_date as event_date,
            ep.ticket_number,
            u.imie as user_name,
            u.nazwisko as user_surname,
            u.nickName
        FROM 
            tickets t
        JOIN 
            events e ON t.event_id = e.id
        JOIN 
            event_participants ep ON t.event_id = ep.event_id AND t.user_id = ep.user_id
        JOIN
            users u ON t.user_id = u.id
        WHERE 
            t.user_id = %s
        ORDER BY
            e.start_date DESC
        """
        cursor.execute(sql_tickets, (user_id,))
        tickets = cursor.fetchall()

        # Konwersja dat na string i decimali na float
        for ticket in tickets:
            if 'purchase_date' in ticket and ticket['purchase_date']:
                ticket['purchase_date'] = ticket['purchase_date'].strftime('%Y-%m-%d %H:%M:%S')
            if 'event_date' in ticket and ticket['event_date']:
                ticket['event_date'] = ticket['event_date'].strftime('%Y-%m-%d %H:%M:%S')
            # Konwersja Decimal na float
            if 'price' in ticket and ticket['price'] is not None:
                ticket['price'] = float(ticket['price'])

        return jsonify(tickets), 200
    except Exception as e:
        print(f"Błąd podczas pobierania biletów: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/ticket/<ticket_number>', methods=['GET'])
def get_ticket_details(ticket_number):
    try:
        cursor = mydb.cursor(dictionary=True)
        
        # Pobieranie szczegółów biletu
        sql = """
        SELECT 
            ep.ticket_number,
            e.id as event_id,
            e.name as event_name, 
            e.location as event_location,
            e.start_date as event_date,
            u.imie as user_name,
            u.nazwisko as user_surname,
            u.id as user_id,
            u.nickName
        FROM 
            event_participants ep
        JOIN 
            events e ON ep.event_id = e.id
        JOIN 
            users u ON ep.user_id = u.id
        WHERE 
            ep.ticket_number = %s
        """
        cursor.execute(sql, (ticket_number,))
        ticket = cursor.fetchone()
        
        if not ticket:
            return jsonify({'error': 'Bilet nie istnieje'}), 404
            
        # Konwersja dat na string
        if 'event_date' in ticket and ticket['event_date']:
            ticket['event_date'] = ticket['event_date'].strftime('%Y-%m-%d %H:%M:%S')
            
        return jsonify(ticket), 200
    except Exception as e:
        print(f"Błąd podczas pobierania szczegółów biletu: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/events/<event_id>', methods=['GET'])
def get_event(event_id):
    try:
        cursor = mydb.cursor(dictionary=True)
        sql = "SELECT * FROM events WHERE id = %s"
        cursor.execute(sql, (event_id,))
        event = cursor.fetchone()
        
        if not event:
            return jsonify({'error': 'Wydarzenie nie istnieje'}), 404
        
        # Konwersja datetime na string i decimal na float
        if 'start_date' in event and event['start_date']:
            event['start_date'] = event['start_date'].strftime('%Y-%m-%d %H:%M:%S')
        
        # Konwersja decimals na float dla JSON serialization
        if 'cena' in event and event['cena'] is not None:
            event['cena'] = float(event['cena'])
            
        # Dodatkowe konwersje
        if 'score' in event and event['score'] is not None:
            event['score'] = int(event['score'])
            
        if 'is_promoted' in event:
            event['is_promoted'] = bool(event['is_promoted'])
        
        return jsonify(event), 200
    except Exception as e:
        print(f"Error in get_event: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    ip = get_local_ip()
    app.run(host=f'{ip}', port=5000,ssl_context=('/etc/letsencrypt/live/vps.jakosinski.pl/fullchain.pem',
                     '/etc/letsencrypt/live/vps.jakosinski.pl/privkey.pem'), debug=True)
