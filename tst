h1. Creating a Synthetic Monitor in Kibana (UI-only)

The Synthetics UI in Kibana lets you stand up an HTTP/TCP/ICMP lightweight monitor or a browser (multistep) monitor in one workflow. The wizard is identical in Elastic Cloud and self-managed clusters; only the available *Locations* list differs.

h2. 1. Open the wizard

# In Kibana's side navigation choose *Observability → Synthetics*.
# Click *Create monitor*. The wizard opens in a fly-out.

h2. 2. Choose a monitor type

||Monitor type||Typical use||Mandatory input||
|HTTP Ping|Check website or REST endpoint|Full URL (https://...)|
|TCP Ping|Verify a service port (DB, SMTP, etc.)|host:port or tcp://host:port|
|ICMP Ping|Basic reachability|Hostname or IP|
|Multistep (Browser)|Simulate a complete user journey|Playwright script (inline)|

Select the type in the *Monitor type* dropdown at the top of the fly-out.

h2. 3. Fill the Basic section (all monitors)

||Field||Description||
|Monitor name|Human-readable label shown in dashboards.|
|Enabled|Toggle to start the monitor immediately (default *On*).|
|Locations|One or more public or Private Locations where the tests run.|
|Frequency|How often the probe executes (20 s–1 h presets).|
|Timeout|Max time allowed before a single check fails (16 s default).|
|Tags (optional)|Arbitrary strings for filtering and alert scopes.|

h2. 4. Protocol-specific inputs

h3. 4.1 HTTP Ping

* *URL(s)* – you can paste multiple URLs separated by commas.
* *Check response* (Advanced → _Response validations_):
** *Expected status codes* (e.g., 200, 3xx)
** *Content match*: positive or negative regex.
* *Request settings* (Advanced → _Request_): method, headers, body, basic auth.
* *TLS*: upload CA, client certificate, set min/max TLS version when hitting {{https}} endpoints.

h3. 4.2 TCP Ping

* *Host* – {{host:port}} or full {{tcp://}} / {{tls://}} URL.
* Optional *Send* and *Expect* payloads to validate banner or echo.

h3. 4.3 ICMP Ping

* *Host* – single hostname or IP.
* *Wait* – delay before a retry when no reply is received (default 1 s).

h3. 4.4 Multistep (Browser)

* *Script editor* – write or paste Playwright steps directly; variables {{page}}, {{params}} are in scope.
* *Script recorder* – launch the Chrome-based recorder to capture a journey and auto-fill the editor.
* *Network throttling, viewport, screenshots* – available under *Advanced options*.
* *Params* – reference Kibana-level parameters with {{params.<name>}} in the script; useful for reusable URLs or credentials.

{code:javascript}
step('Navigate to login page', async () => {
  await page.goto(`${params.url}/login`);
});

step('Fill credentials', async () => {
  await page.fill('#username', params.username);
  await page.fill('#password', params.password);
});

step('Submit login', async () => {
  await page.click('#login-button');
  await page.waitForSelector('[data-testid="dashboard"]');
});
{code}

h2. 5. Validate and save

# Click *Run test* (optional) to execute once and see immediate results in the fly-out.
# When the test is green, click *Create monitor*.
# The wizard closes and the new monitor appears in the *Monitors* list; the first scheduled run starts within the configured frequency window.

h2. 6. What happens next

* The monitor details page shows availability, latency, and screenshots (for browser checks) minutes after creation.
* You can edit, clone, or delete the monitor at any time via the *pencil / trash* icons in the list; edits reopen the same fly-out with current values pre-filled.

{info:title=Pro Tip}
Keep monitor scripts and URLs environment-agnostic by using *Global parameters*. Define them once in *Synthetics → Settings → Global parameters* and reference them as {{${param}}} (lightweight) or {{params.param}} (browser).
{info}

{panel:title=Summary|borderStyle=solid|borderColor=#ccc|titleBGColor=#f7f7f7|bgColor=#ffffff}
With these steps you can spin up fully functional synthetic monitors entirely from the Kibana UI—no CLI, YAML, or external configuration required.
{panel}
