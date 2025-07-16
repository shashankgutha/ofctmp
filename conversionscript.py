import os
import json
import yaml
import re
import argparse

# --- Helper Functions ---

def sanitize_filename(name):
    """
    Sanitizes a string to be used as a valid filename.
    Replaces spaces with underscores and removes characters that are not
    alphanumeric, underscores, or hyphens.
    """
    name = name.replace(' ', '_')
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    return name.lower()

def create_browser_monitor_file(monitor, output_dir):
    """
    Generates a.journey.ts file for a browser monitor.
    """
    # Ensure the 'journeys' directory exists
    journeys_dir = os.path.join(output_dir, 'journeys')
    os.makedirs(journeys_dir, exist_ok=True)

    # Extract monitor details, providing sensible defaults
    monitor_id = monitor.get('id', 'browser-monitor')
    monitor_name = monitor.get('name', 'Browser Journey')
    schedule = monitor.get('schedule', 10)
    locations = monitor.get('locations',)
    private_locations = monitor.get('private_locations',)
    tags = monitor.get('tags',)
    
    # The script content is assumed to be in a 'content' or 'script' field
    script_content = monitor.get('content') or monitor.get('script', "# Add your journey steps here\nstep('Step 1: Load the page', async () => {\n  // Your Playwright code goes here\n});")

    # Construct the monitor.use() configuration object
    config = {
        'id': monitor_id,
        'name': monitor_name,
        'schedule': schedule,
        'tags': tags
    }
    if locations:
        config['locations'] = locations
    if private_locations:
        config['privateLocations'] = private_locations

    # Use a multiline string to create the TypeScript file content
    ts_content = f"""
import {{ journey, step, monitor }} from '@elastic/synthetics';

journey('{monitor_name}', ({{ page, params }}) => {{
  monitor.use({json.dumps(config, indent=4)});

  {script_content}
}});
"""
    # Generate a sanitized filename and write the file
    filename = f"{sanitize_filename(monitor_name)}_{monitor_id}.journey.ts"
    filepath = os.path.join(journeys_dir, filename)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(ts_content.strip())
    print(f"Successfully created browser monitor: {filepath}")


def create_lightweight_monitor_file(monitor, output_dir):
    """
    Generates a.yml file for a lightweight (http, tcp, icmp) monitor.
    """
    # Ensure the 'lightweight' directory exists
    lightweight_dir = os.path.join(output_dir, 'lightweight')
    os.makedirs(lightweight_dir, exist_ok=True)

    # Extract common monitor details
    monitor_id = monitor.get('id', 'lightweight-monitor')
    monitor_name = monitor.get('name', 'Lightweight Monitor')
    monitor_type = monitor.get('type')
    
    # Build the YAML structure
    yaml_data = [
        {
            'id': monitor_id,
            'name': monitor_name,
            'type': monitor_type,
            'schedule': monitor.get('schedule', 10),
            'locations': monitor.get('locations',),
            'private_locations': monitor.get('private_locations',),
            'tags': monitor.get('tags',),
            'enabled': monitor.get('enabled', True)
        }
    ]
    
    # Add type-specific configuration
    if monitor_type == 'http':
        yaml_data['url'] = monitor.get('url', 'http://example.com')
        # Add other http-specific fields if they exist in your JSON
        if 'check' in monitor:
            yaml_data['check'] = monitor['check']

    elif monitor_type == 'tcp':
        yaml_data['host'] = monitor.get('host', 'localhost')
        yaml_data['port'] = monitor.get('port', 80)

    elif monitor_type == 'icmp':
        yaml_data['host'] = monitor.get('host', 'localhost')

    # Generate a sanitized filename and write the file
    filename = f"{sanitize_filename(monitor_name)}_{monitor_id}.yml"
    filepath = os.path.join(lightweight_dir, filename)

    with open(filepath, 'w', encoding='utf-8') as f:
        yaml.dump(yaml_data, f, sort_keys=False, default_flow_style=False)
    print(f"Successfully created lightweight monitor: {filepath}")


# --- Main Execution ---

def main():
    """
    Main function to parse arguments and process the monitor JSON file.
    """
    parser = argparse.ArgumentParser(
        description="Convert a JSON export of Elastic Synthetics monitors into a project file structure."
    )
    parser.add_argument("json_file", help="Path to the input JSON file containing the monitor configurations.")
    parser.add_argument("output_dir", help="Path to the output directory where the project files will be created.")
    args = parser.parse_args()

    # Create the base output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)

    try:
        with open(args.json_file, 'r', encoding='utf-8') as f:
            monitors = json.load(f)
    except FileNotFoundError:
        print(f"Error: The file '{args.json_file}' was not found.")
        return
    except json.JSONDecodeError:
        print(f"Error: The file '{args.json_file}' is not a valid JSON file.")
        return

    # Process each monitor from the JSON file
    for monitor in monitors:
        monitor_type = monitor.get('type')
        if monitor_type == 'browser':
            create_browser_monitor_file(monitor, args.output_dir)
        elif monitor_type in ['http', 'tcp', 'icmp']:
            create_lightweight_monitor_file(monitor, args.output_dir)
        else:
            print(f"Warning: Skipping monitor with unknown type '{monitor_type}': {monitor.get('name')}")

if __name__ == "__main__":
    main()
