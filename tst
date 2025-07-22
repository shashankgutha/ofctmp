def process_k8s_secrets(self, config_content):
    """Process K8SSEC_ prefixed values and convert to Kubernetes ${} format"""
    import re
    
    # Process in multiple passes to handle different patterns
    processed_content = config_content
    
    # Pattern 1: Handle QK8SSEC_ (Q prefix for single quotes)
    def replace_q_k8s_secret(match):
        secret_name = match.group(1)
        return f"'${{{secret_name}}}'"
    
    q_pattern = r'QK8SSEC_([A-Za-z_][A-Za-z0-9_.]*)'
    processed_content = re.sub(q_pattern, replace_q_k8s_secret, processed_content)
    
    # Pattern 2: Handle regular K8SSEC_ (with or without quotes)
    def replace_regular_k8s_secret(match):
        secret_name = match.group(1)
        return "${" + secret_name + "}"
    
    # This pattern matches K8SSEC_ followed by alphanumeric/underscore/dot characters
    # It stops at word boundaries or common delimiters
    regular_pattern = r'K8SSEC_([A-Za-z_][A-Za-z0-9_.]*?)(?=\s|$|"|\'|,|;|:|\)|\]|\}|$)'
    processed_content = re.sub(regular_pattern, replace_regular_k8s_secret, processed_content)
    
    # Count and log replacements
    q_matches = re.findall(r'QK8SSEC_([A-Za-z_][A-Za-z0-9_.]*)', config_content)
    regular_matches = re.findall(r'(?<!Q)K8SSEC_([A-Za-z_][A-Za-z0-9_.]*)', config_content)
    
    total_matches = len(q_matches) + len(regular_matches)
    if total_matches > 0:
        print(f"Converted {total_matches} K8SSEC_ references to Kubernetes secrets:")
        for match in q_matches:
            print(f"  QK8SSEC_{match} -> '${{{match}}}'")
        for match in regular_matches:
            print(f"  K8SSEC_{match} -> ${{{match}}}")
    
    return processed_content
