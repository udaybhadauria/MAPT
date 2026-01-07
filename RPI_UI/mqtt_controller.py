import paho.mqtt.client as mqtt
import json
import subprocess
import os

BROKER = "fd22:2456:289a::1"  # RPI_UI IPv6 address
PORT = 1883

BASE_DIR = "/root/RPI_UI"  # adjust to your actual RPI_UI path

TOPIC_CONFIG = "rpi_jool/config"
TOPIC_STATUS = "rpi_jool/status"
TOPIC_OUTPUT = "rpi_jool/output"
TOPIC_SERVICES = "rpi_jool/services_status"

STATUS_FILE = os.path.join(BASE_DIR, "status.json")
OUTPUT_FILE = os.path.join(BASE_DIR, "output.json")
CONFIG_FILE = os.path.join(BASE_DIR, "config_ui.json")
TMP_FILE = os.path.join(BASE_DIR, "output.json.tmp")
SERVICES_FILE = os.path.join(BASE_DIR, "services_status.json")

#STATUS_FILE = "status.json"
#OUTPUT_FILE = "output.json"
#CONFIG_FILE = "config_ui.json"
#TMP_FILE = "output.json.tmp"

client = mqtt.Client()

def on_message(client, userdata, msg):
    if msg.topic == TOPIC_STATUS:
        with open(STATUS_FILE, "wb") as f:
            f.write(msg.payload)
        print("Status updated")
    elif msg.topic == TOPIC_OUTPUT:
        with open(OUTPUT_FILE, "wb") as f:
            f.write(msg.payload)
        print("Output updated")
    elif msg.topic == TOPIC_SERVICES:
        with open(SERVICES_FILE, "wb") as f:
            f.write(msg.payload)
        print("Services status updated")

client.on_message = on_message
client.connect(BROKER, PORT)
client.subscribe(TOPIC_STATUS)
client.subscribe(TOPIC_OUTPUT)
client.subscribe(TOPIC_SERVICES)
client.loop_start()

def push_config():
    # Delete old status/output files to avoid stale data
    for f in [OUTPUT_FILE, STATUS_FILE]:
        if os.path.exists(f):
            os.remove(f)

    with open(CONFIG_FILE, "rb") as f:
        client.publish(TOPIC_CONFIG, f.read(), qos=1)
    print("Configuration has been successfully pushed to the MAP-T server.")

def on_output_message(payload: bytes):
    with open(TMP_FILE, "wb") as f:
        f.write(payload)

    # atomic on Linux
    os.replace(TMP_FILE, OUTPUT_FILE)
