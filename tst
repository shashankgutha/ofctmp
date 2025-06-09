import requests
from requests.auth import HTTPBasicAuth
from elasticsearch import Elasticsearch, helpers

# (1) Configure base URL and auth
host = "your-company.aternity.com"
endpoint = f"https://{host}/aternity.odata/v2/BUSINESS_ACTIVITIES_HOURLY"
auth = HTTPBasicAuth("your_username", "your_password")

# (2) Fetch first page of data
params = {"$format": "json", "$top": 5000}   # request JSON; adjust $top as needed
resp = requests.get(endpoint, auth=auth, params=params, verify=True)
resp.raise_for_status()
data = resp.json()

# (3) Collect records and follow pagination
records = data.get("value", [])
while "@odata.nextLink" in data:
    next_url = data["@odata.nextLink"]
    resp = requests.get(next_url, auth=auth, verify=True)
    resp.raise_for_status()
    data = resp.json()
    records.extend(data.get("value", []))

print(f"Retrieved {len(records)} records from BUSINESS_ACTIVITIES_HOURLY")

clean_records = []
for rec in records:
    rec_clean = {k: v for k,v in rec.items() if not k.startswith("@")}
    clean_records.append(rec_clean)

# (1) Connect to Elasticsearch (adjust host/port as needed)
es = Elasticsearch("http://localhost:9200")

# (2) Prepare bulk actions
actions = []
index_name = "aternity-activities"   # choose your index name
for rec in clean_records:
    # Optionally add an explicit index or id here
    actions.append({
        "_index": index_name,
        "_source": rec
    })

# (3) Create the index with mapping (if not exists)
# (Mapping should be defined beforehand for proper data types; see next section.)

# (4) Bulk-index the data
helpers.bulk(es, actions)
print(f"Indexed {len(clean_records)} records into {index_name}")
