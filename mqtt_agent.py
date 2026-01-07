import paho.mqtt.client as mqtt
import subprocess
import json
import os
import threading
import time

BROKER = "fd22:2456:289a::1"  # RPI_UI
PORT = 1883

TOPIC_CONFIG = "rpi_jool/config"
TOPIC_STATUS = "rpi_jool/status"
TOPIC_OUTPUT = "rpi_jool/output"
TOPIC_SERVICES = "rpi_jool/services_status"

CONFIG_FILE = "config_ui.json"
STATUS_FILE = "status.json"
OUTPUT_FILE = "output.json"
SERVICES_FILE = "services_status.json"

client = mqtt.Client()

def publish_file(topic, filename):
    if os.path.exists(filename):
        with open(filename, "rb") as f:
            client.publish(topic, f.read(), qos=1, retain=False)

def run_script(script_name, cwd="/root/ui_jool"):
    """Run a bash script and raise exception if it fails."""
    result = subprocess.run(["bash", script_name], cwd=cwd)
    if result.returncode != 0:
        raise RuntimeError(f"Script {script_name} failed with exit code {result.returncode}")

def on_message(client, userdata, msg):
    if msg.topic == TOPIC_CONFIG:

        # Save received UI config
        with open(CONFIG_FILE, "wb") as f:
            f.write(msg.payload)

        # Status: applying
        with open(STATUS_FILE, "w") as f:
            json.dump({"state": "applying"}, f)
        publish_file(TOPIC_STATUS, STATUS_FILE)

        try:
            # 1️⃣ Validate JOOL MAP-T
            run_script("jool_validate_apply.sh")

            # 2️⃣ Generate mac & IPv6 mapping
            run_script("generate_mac_ipv6.sh")

            # Immediately publish output.json after generation
            publish_file(TOPIC_OUTPUT, OUTPUT_FILE)

            # 3️⃣ Generate Kea DHCP6 config
            run_script("generate_kea_dhcp6.sh")

            # 4️⃣ Add neighbor entries
            run_script("add_neighbor_entries.sh")

            # Status: done
            with open(STATUS_FILE, "w") as f:
                json.dump({"state": "done"}, f)
            publish_file(TOPIC_STATUS, STATUS_FILE)

        except Exception as e:
            # Status: error
            with open(STATUS_FILE, "w") as f:
                json.dump({"state": "error", "reason": str(e)}, f)
            publish_file(TOPIC_STATUS, STATUS_FILE)

def service_status_loop():
    while True:
        try:
            # Run your shell script that writes services_status.json
            run_script("check_services.sh")  

            # Check if file exists, then publish
            if os.path.exists(SERVICES_FILE):
                with open(SERVICES_FILE, "rb") as f:
                    client.publish(TOPIC_SERVICES, f.read(), qos=1)
            else:
                print(f"[services] {SERVICES_FILE} not found, skipping publish")

        except Exception as e:
            print(f"[services] error: {e}")

        time.sleep(10)


client.on_message = on_message
client.connect(BROKER, PORT)
client.subscribe(TOPIC_CONFIG)

# 🔁 Start background services publisher
threading.Thread(target=service_status_loop, daemon=True).start()

client.loop_forever()
