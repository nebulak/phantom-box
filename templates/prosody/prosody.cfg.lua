pidfile = "/var/run/prosody/prosody.pid"

--
-- Datenbankanbindung
---------------------------------

storage = "sql"

sql = {
    driver = "MySQL";
    database = "prosody";
    host = "localhost";
    username = "prosody";
    password = "prosodypasswort";
}


--
-- Authentifizierung
---------------------------------

-- Passwörter gehashed abspeichern
authentication = "internal_hashed"

-- Admin-Account festlegen
admins = { "admin@xmppserver.tld" }


--
-- TLS Konfiguration
---------------------------------

-- Verschlüsselte Verbindungen zu Clients und Servern erzwingen
c2s_require_encryption = true;
s2s_require_encryption = true;

-- Server müssen anerkannte, gültigen Sicherheitszertifikate vorweisen
-- Siehe auch: https://thomas-leister.de/sichere-xmpp-s2s-verschluesselung/
s2s_secure_auth = false;

ssl = {
    options = { "no_sslv2", "no_sslv3", "no_compression" };

    dhparam = "/etc/myssl/dh2048.pem";
    key = "/etc/myssl/privkey.pem";
    certificate = "/etc/myssl/fullchain.pem";
}


--
-- Prosody Module
---------------------------------

-- Pfad zu den Prosody-Modulen
plugin_paths = { "/opt/prosody-modules" }

-- Aktivierte Module (global, für alle vHosts)
modules_enabled = {
    -- Wichtige Module
    "roster";
    "saslauth";
    "tls";
    "dialback";
    "disco";

    -- Empfohlene Module
    "private";
    "vcard";
    "offline";
    "admin_adhoc";
    "http";

    -- Nice to have
    "legacyauth";
    "version";
    "uptime";
    "time";
    "ping";
    "register_web";
    "register";
    "posix";
    "bosh";
    "announce";
    "proxy65";
    "pep";
    "smacks";
    "carbons";
    "blocking";
    "http_upload";
    "csi";
    "throttle_presence";
    "mam";
    "lastlog";
    "cloud_notify";
    "compat_dialback";
};


--
-- Logging
----------------------------------
log = {
 debug = "/var/log/prosody/prosody.log";
 error = "/var/log/prosody/prosody.err";
}


--
-- Register Web Template files
-- (Kann auch entfernt werden, dann wird Standard-Template genutzt)
----------------------------------

-- register_web_template = "/etc/prosody/register-templates/Prosody-Web-Registration-Theme";


--
-- MAM settings
-- (Chats nicht standardmäßig loggen, nach einem Monat vom Server löschen)
----------------------------

default_archive_policy = false;
archive_expires_after = "1m";


--
-- HTTP Config
----------------------------------

http_default_host = "xmppserver.tld"

http_paths = {
    register_web = "/register";
}

-- BOSH-Funktionalität auch für Clients auf anderen Domains freigeben
-- BOSH steht unter https://xmppserver:5281/http-bind/ zur Verfügung
cross_domain_bosh = true;


--
-- Service Discovery
----------------------------------

-- Multi-User-Chat (MUC) soll als verfügbarer XMPP Dienst aufgeführt werden
disco_items = {
    { "conference.xmppserver.tld", "The xmppserver.tld MUC" };
}


--
-- XMPP VirtualHosts
------------------------------------

-- xmppserver.tld als einziger XMPP-vHost
VirtualHost "xmppserver.tld"
    allow_registration = true
    min_seconds_between_registrations = 60

    http_host = "xmppserver.tld"

    -- Einstellungen zum MUC
    Component "conference.xmppserver.tld" "muc"
        name = "Xmppserver.tld Chatrooms"
        restrict_room_creation = false
        max_history_messages = 100