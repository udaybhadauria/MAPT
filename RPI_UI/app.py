from flask import Flask, render_template, request, jsonify, make_response
import json
import os
import time
from mqtt_controller import push_config  # your existing module

app = Flask(__name__)
app.secret_key = "supersecretkey"  # needed for flash messages
CONFIG_FILE = "config_ui.json"
OUTPUT_FILE = "output.json"
STABILITY_WINDOW = 0.5  # seconds
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICES_FILE = os.path.join(BASE_DIR, "services_status.json")

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        data = request.form.to_dict(flat=False)

        # Build JSON from form data
        config = {
            "dhcp6": {
                "subnet": data.get("subnet")[0],
                "pool": {
                    "start": data.get("pool_start")[0],
                    "end": data.get("pool_end")[0]
                },
                "dns": [d.strip() for d in data.get("dns") if d.strip()]
            },
            "s46": {  # readonly values
                "v4_prefix": "192.168.12.0",
                "v4_plen": 24,
                "ea_len": 14,
                "v6_rule_prefix": "2600:8809:a504::/46",
                "dmr": "2600:8809:bfff:ffff::/64"
            },
            "devices": []
        }

        # Add devices from form
        macs = data.get("mac[]")
        psids = data.get("psid[]")

        for i in range(len(macs)):
            config["devices"].append({
                "mac": macs[i],
                "psid": int(psids[i]),
                "psid_len": 6  # fixed
            })

        # Save config to file
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=2)

        # Push config via MQTT
        push_config()

        # Return JSON for fetch()
        return jsonify({"status": "Config pushed to MAPT Server successfully!"})

    # GET request
    try:
        with open(CONFIG_FILE) as f:
            config = json.load(f)
    except Exception:
        config = {}

    return render_template("index.html", config=config)

@app.route("/output.json", methods=["GET"])
def output_json():
    if not os.path.exists(OUTPUT_FILE):
        return jsonify({"status": "No output yet"}), 202  # Not ready yet

    try:
        with open(OUTPUT_FILE) as f:
            data = json.load(f)
    except Exception:
        return jsonify({"status": "Output not ready"}), 202

    # If data is empty or invalid
    if not isinstance(data, dict) or not data:
        return jsonify({"status": "Output empty"}), 202

    # ✅ Ready
    resp = make_response(jsonify(data))
    resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    resp.headers["Pragma"] = "no-cache"
    resp.headers["Expires"] = "0"
    resp.headers["ETag"] = ""
    return resp, 200

@app.route("/services_status.json")
def services_status():
    if not os.path.exists(SERVICES_FILE):
        return jsonify({"status": "waiting"}), 202

    with open(SERVICES_FILE) as f:
        return jsonify(json.load(f))


if __name__ == "__main__":
    # Run Flask app
    app.run(host="0.0.0.0", port=8282)
