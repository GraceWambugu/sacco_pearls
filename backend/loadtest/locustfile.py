"""Load test for the member-facing API (proposal section 3.6: under 2 seconds).

Run from backend, with the API already running on port 8000:
    ..\.venv\Scripts\python.exe -m locust -f loadtest/locustfile.py --host http://127.0.0.1:8000 \
        --headless -u 50 -r 10 -t 2m --csv ../docs/chapter4/loadtest/results

Each simulated member does what a real one does in the app: search, open a
profile, compare, look at rankings and a trend, with a short pause between taps.
"""
import random

from locust import HttpUser, between, task


class Member(HttpUser):
    wait_time = between(1, 3)  # seconds between taps, like a person reading the screen

    def on_start(self):
        # Use real SACCO ids so every request hits real data.
        # Reported separately: every simulated member arrives at once during ramp-up.
        self.ids = [s["id"] for s in self.client.get("/saccos?limit=200", name="/saccos (start-up burst)").json()]

    @task(1)
    def directory(self):
        self.client.get("/saccos?limit=200", name="/saccos (directory)")

    @task(3)
    def search(self):
        self.client.get(f"/saccos?q={random.choice(['stima', 'police', 'mwalimu', 'teachers', 'kenya'])}",
                        name="/saccos?q= (search)")

    @task(4)
    def profile(self):
        with self.client.get(f"/saccos/{random.choice(self.ids)}/score", name="/saccos/{id}/score (profile)",
                             catch_response=True) as r:
            # 404 "no figures loaded" is the correct answer for a SACCO with no data at all.
            if r.status_code == 404:
                r.success()

    @task(2)
    def compare(self):
        ids = ",".join(str(i) for i in random.sample(self.ids, 3))
        with self.client.get(f"/compare?ids={ids}", name="/compare (3 SACCOs)", catch_response=True) as r:
            # 404 is a correct answer when three SACCOs share no year (e.g. one only has 2020 figures).
            if r.status_code == 404:
                r.success()

    @task(1)
    def rankings(self):
        self.client.get("/rankings?limit=200", name="/rankings (home + directory)")

    @task(2)
    def trend(self):
        self.client.get(f"/saccos/{random.choice(self.ids)}/trend", name="/saccos/{id}/trend")
